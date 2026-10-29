---
tags: [fundamentals, replication, networking, ownership, type/guide, area/animation, level/beginner, api/Animator, area/networking, api/Humanoid]
---
# Replication and Ownership

<!-- tldr:start -->
> [!tldr] TL;DR
> - All replication of playing tracks goes through the Animator.
> - If the Animator is a descendant of a player's character (under its Humanoid or an AnimationController in it), tracks started...
> - If the Animator is not under a player's character, tracks must be loaded and started on the server to replicate.
> - Remote viewers see the same clip a little later, by roughly the owner-to-server-to-viewer latency.
>
> Cost: TL;DR ~140 tok · whole note ~2.8k tok. Read more: ## The documented rules · ## Architecture 3: server writes state, every client animates (scales)
<!-- tldr:end -->

Who plays an animation decides who sees it, how late they see it, how much bandwidth it costs, and whether the server can trust its timing. This note covers the Animator's replication rules (documented), what does and does not replicate (including the parts the docs leave implicit), how ownership interacts with it, and the three architectures that scale: owner-plays, server-plays, and server-writes-state with client playback. Asset ownership (whether a clip is *allowed* to load at all) is a separate topic: see [[Animation Asset Permissions and Groups]].

## The documented rules

From the `Animator` and `Animation` reference pages:
1. **All replication of playing tracks goes through the Animator.**
2. If the Animator is a descendant of a **player's character** (under its Humanoid or an AnimationController in it), tracks **started on that player's client** replicate to the server and to all other clients.
3. If the Animator is **not** under a player's character, tracks must be **loaded and started on the server** to replicate.
4. The Animator must be **created on the server** and replicated. An Animator created on a client does not replicate tracks, ever.
5. On a model the client has network ownership of (its own character), `LoadAnimation` also loads the animation for the server.

| Rig | Play on | Others see it? |
|---|---|---|
| Your own character | Your client (LocalScript) | Yes |
| Your own character | Server | Yes |
| Another player's character | Your client | **Only you** |
| NPC / prop / weapon not inside a character | Server | Yes |
| NPC / prop | A client | **Only that client** |
| Any rig with a client-created Animator | Anywhere | **Only that client** |

The third and fifth rows are features, not bugs: they let each client play purely cosmetic animation locally with no network cost (see the server-writes-state pattern below).

## What replicates and what does not

| Replicates (track state through the Animator) | Does not replicate |
|---|---|
| Which clip (asset id) | `Motor6D.Transform`, `AnimationConstraint.Transform`, `Bone.Transform` |
| Play / Stop with fade times | Anything you write procedurally in `PreSimulation` |
| Weight changes, speed changes | Clip contents (each client downloads the asset itself) |
| Priority and looping (carried by the internal replication event) | Tracks of a client-created Animator |
| Time position at start (approximately) | Marker events as such (each client fires its own) |

Every client evaluates every replicated track itself and writes its own joint transforms. Two consequences:
- **Remote viewers see the same clip a little later**, by roughly the owner-to-server-to-viewer latency. Gameplay timing must not depend on what remote viewers see.
- **Procedural layers must run on every client.** A head-look computed only on the owner's client is invisible to everyone else. Replicate the *input* (look direction as an attribute or through an `UnreliableRemoteEvent`) and run the same procedural code everywhere. Roblox's own migration guidance for the Avatar Joint Upgrade says the same: do not replicate C0 from the server; evaluate on the client and sync data.

## Ownership and character physics

- A player's character root is network-owned by that player's client: their client simulates the character, runs the Humanoid state machine, and its animation is lowest-latency when played there.
- Server-owned NPCs are simulated by the server; the server's Animator evaluates their tracks so part positions are correct for physics and hit detection on the server.
- You can hand an NPC's ownership to a client (`BasePart:SetNetworkOwner`) for smoother local physics, but its animation replication still follows the rules above (an NPC is not a player character, so play its tracks on the server).
- Humanoid state calls (`ChangeState`) only work on the owner; `SetStateEnabled` does not replicate. See [[Humanoid States and Animation]].

## Architecture 1: owner plays (player characters)

The normal case: the LocalScript that handles input plays the clip on the player's own character.
- Instant feedback for the player.
- Everyone else sees it through Animator replication.
- The server sees it too, late, and **must not trust it** for damage. Use data timing (marker times extracted at build time) and validate client hit claims against it (see [[Markers and Events]]).

### Relaying effects with the move
The animation replicates itself, but effects tied to it (VFX, sound, camera beats) usually need a relay:
1. Caster's client plays the clip and effects immediately.
2. It fires a RemoteEvent with the move id.
3. The server validates: rate limit (one production game used 1 per second for equip flourishes), that the move belongs to the held weapon (a Tool attribute), that the player is alive and not stunned.
4. The server relays to other clients, which play only the effects (the clip already replicated).

Never relay raw CFrames per frame. One game computed the blade's in-hand offset (spins, tosses) **on every client from shared data** (flourish name, start time) instead of replicating the grip CFrame.

## Architecture 2: server plays (simple NPCs)

The server loads and plays NPC tracks; everyone sees them.
- Simple and authoritative: server hitboxes follow the animated parts.
- Costs server CPU per animated NPC every frame and bandwidth for every track change.
- Clients see NPC motion late by their own latency.

Good for a handful of important NPCs. It does not scale to hundreds.

## Architecture 3: server writes state, every client animates (scales)

For many NPCs, the server skips animation entirely and writes small replicated attributes; each client plays the matching clips locally on its own copy of the rig. One production enemy system used:

| Attribute | Meaning |
|---|---|
| `Anim`, `AnimT`, `AnimSpeed`, `AnimLoop` | Current clip, server start time, speed, loop flag |
| `Hurt` | Directional hit reaction to play (`HitFront`, `HeavyHit`...) |
| `Layer` | An additive/overlay layer and its timing |
| `Detach_<key>` | Hide or drop a detachable part |
| `Fade`, `Phase` | Fade-out on death, boss phase (texture swaps, clip sets) |

How it works:
- The server's AI decides "attack now" and writes the attribute with the server time. Its damage timing comes from **data** (mark times in the enemy definition, or [[KeyframeMarker]] times exported from the clip). It never loads the clip.
- Each client reacts to the attribute change, plays the clip, and **joins late** by `TimePosition = (serverNow - AnimT) * AnimSpeed` so all clients are in sync regardless of when they received the update. Combos continue part-way into the next clip via a time-offset attribute.
- Clients LOD the animation by distance and cull off-screen enemies.

| Pros | Cons |
|---|---|
| Server CPU near zero for animation | Server hitboxes do not follow animation: hits must be data-driven (distances, arcs, marker times) |
| Bandwidth: a few attributes per action instead of continuous track state | Clients can disagree slightly on pose (harmless for cosmetics) |
| Each client can LOD and cull independently | More code: a client animator per enemy family |
| Works with clips the server never loads | Debugging needs both sides |

See [[Enemy Animation State Protocol]] and [[Snippets - Enemy Client Animator]].

## Custom Lua players and replication

A Lua keyframe player that writes `Transform` itself has **no** built-in replication: you must build it. One production player did:
- Local-character tracks are batched and throttled through a RemoteEvent to a server relay, then to every other client, each of which plays its own copy on that player's character.
- Speed changes are sent at once when they change by 6% or more, otherwise at most every 0.25 s; per-frame weight changes are sent only when they really change, at most 4 per second.
- Clip identity travels as a key (a ReplicatedStorage path, or a path plus a list of joints switched off for runtime upper-body copies); metadata rides along as attributes on the Animation.
- Late joiners request the currently active tracks.

These numbers are a good starting point if you build the same thing. The real Animator's own throttling of weight/speed updates is undocumented; avoid calling `AdjustWeight` or `AdjustSpeed` every frame on replicated tracks without need.

## Synchronised one-off animation without tracks

For a world animation everyone must see in sync (a gate opening, a shrine spinning), replicate one attribute and let each client run the same deterministic animation:
```lua
-- Server: trigger. The value is unique per trigger so repeated triggers still fire Changed.
gate:SetAttribute("Spin", string.format("%d:%d:%d", player.UserId, index, serial))
-- Clients: on change, run the same 4.4 s quartic-eased spin locally (TweenService or a PreRender loop).
```
One game used exactly this for a 4.4 s ceremonial spin. No streaming of CFrames, perfect smoothness on every client.

## Studio-only clips look like a replication bug

`KeyframeSequenceProvider:RegisterKeyframeSequence` and `AnimationClipProvider:RegisterAnimationClip` ids only load in Studio. In a live server they load nothing, everywhere, silently. Because everything works in Play Solo, teams often misdiagnose this as "animations don't replicate". If a clip works in Studio and does nothing live for **everyone including the player**, it is an id problem (temporary id or permissions), not replication. See [[Publishing Animations]] and [[Case Study - Abilities That Only Worked in Studio]].

## Diagnosing

| Symptom | Cause |
|---|---|
| You see your animation, others do not | Animator created on the client; or you played on another player's character or an NPC from a client |
| Nobody sees it, including you, live only | Studio-only id or missing permission |
| Others see it late or slightly out of sync | Normal latency; do not time gameplay from remote views |
| Head-look / IK only visible to the owner | Procedural layer runs only on the owner |
| NPC animations stutter for far players | Client animator LOD or throttling (`ClientAnimatorThrottling`, `PreferLodEnabled`) |
| Server hit detection misses animated swings | Using server parts for a client-animated NPC; switch to data-driven hits |

## See also
[[Animator Deep Dive]] · [[Animation Asset Permissions and Groups]] · [[Publishing Animations]] · [[Markers and Events]] · [[Enemy and NPC Animation]] · [[Enemy Animation State Protocol]] · [[Lua Keyframe Player]] · [[Humanoid States and Animation]]

## Connected notes
<!-- auto-links:start -->
[[Snippets - Lua Keyframe Player Core]] · [[Animation Objects]] · [[Replication Rules]] · [[Engine Gotchas]] · Client-Server Model · Replication Boundary · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Client-Server Model]] · [[AnimationTrack Reference]] · [[Animation LOD]] · [[Snippets - Playing Animations]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Debugging Animation Problems]] · [[Playback, Priorities and Blending]] · [[How the Animator Really Behaves]] · [[Performance and Memory]]
<!-- related:end -->
