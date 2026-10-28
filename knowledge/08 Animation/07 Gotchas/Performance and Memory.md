---
tags: [performance, memory, budgets, gotchas]
---
# Performance and Memory

<!-- tldr:start -->
> [!tldr] TL;DR
> - No `RBX_ANIMSAVES`, `AnimSaves` or backup clip folders shipped.
> - Kit folders under budget (2,500 used); per-move instance counts known.
> - Keys thinned; placeholders pruned; marker keyframes kept.
> - Clips that are not edited this week are stubbed or published.
> - Tracks cached per Animator; marker connections bounded.
> - One shared update loop for Lua players and procedural motion.
>
> Read more (14 KB note): ## 1. Instance counts: the hidden cost · ## 3. Per-frame CPU · ## Checklist
<!-- tldr:end -->

Animation costs you in three places, and they need different fixes:

1. **Instances** (load time and memory): every `Keyframe`, `Pose` and `KeyframeMarker` is an Instance. Clips stored as `KeyframeSequence`s in ReplicatedStorage are downloaded by every client at join.
2. **Per-frame CPU**: the engine Animator's evaluation, your own Lua players and procedural code, and moving many parts.
3. **Tracks and connections** (slow leaks): tracks loaded and never released, marker connections never disconnected.

Most "animation lag" in the reference project (one live action game) was the first kind, which is surprising, because nobody feels Instances as lag until join times and Studio frame rates collapse.

---

## 1. Instance counts: the hidden cost

### Where the instances come from
A `KeyframeSequence` costs:
- 1 instance for the sequence,
- 1 per `Keyframe`,
- 1 per `Pose` on each keyframe (weighted keys **and** weight-0 placeholders that hold the hierarchy together),
- 1 per `KeyframeMarker`.

A full R15 key has 15 Poses (HumanoidRootPart placeholder plus 14 joints). A clip baked "every joint keyed at 16 to 25 fps" is therefore roughly `fps x seconds x 16` instances: a 2 s clip at 20 fps is about 640 instances. Multiply by every move of every weapon and every enemy and you get the numbers below.

### What it looked like in one production game (measured)
| Where | Count |
|---|---|
| ReplicatedStorage, before cleanup | about 600k instances, including enemy animations at 323k |
| `RBX_ANIMSAVES` (importer and editor saves) | 642k |
| A pose-thinning backup folder | 512k |
| A boss re-key backup | about 385k |
| An enemy work-in-progress set | 112k |
| Enemy model copies of their own `Animations` folders, destroyed on every spawn anyway | 207k |
| Clips of 12 enemies no longer in the game | 69k |

Reductions on record:
- Whole place: about 2.36M to 955k after archiving `RBX_ANIMSAVES` and imports; a later cleanup deleted another 191,089.
- Player kit clips stubbed: ReplicatedStorage 392k to 107k on every client.
- Enemy clips stubbed (well over a thousand clips, dozens of kits): ServerStorage 1.96M to 712k, then 420k after archiving.
- Weapon-part clips stubbed: ReplicatedStorage 108,403 to 82,847 to 68,557.

Studio itself slowed to about 15 fps with the place past roughly 1M instances (measured on one machine). That alone is a reason to keep source clips out of the place.

### Per-key cost arithmetic (from the arm baker)
When a tool adds keys to an existing clip:
- Each extra key on one arm costs 3 Poses (upper arm, lower arm, hand).
- A new keyframe time costs 1 Keyframe plus 3 placeholders (HumanoidRootPart, LowerTorso, UpperTorso) before any real pose is added.

So adding keys at existing keyframe times is far cheaper than adding new times. The reference baker snapped split points to an existing keyframe within 2 to 3 frames for exactly this reason. See [[Arm Baker Internals]].

### Budgets that worked
| Budget | Value | Source |
|---|---|---|
| Weapon kit folder (moves + weapon-part clips + scripts) | 2,500 instances | Project budget |
| Normal move clip density | about 22 to 30 keys/s | Measured average |
| Ultimates | about 15 to 19 keys/s (to fit the budget) | Measured |
| Weapon-part clip set | under 80 instances | Project budget |
| Generated clip of a big ult | up to 719 instances | Measured worst |
| Clip growth allowed per re-bake | 15% + 30 instances | Baker rule |

Some legacy kits sat at 2,973 to 5,363 instances and could only take "no growth" re-bakes. Weapon-part clips sampled every 0.05 s blew the cap on their own; thinning to keys every 0.12 to 0.19 s fixed one weapon.

### Fixes, cheapest first
1. **Delete dead weight.** `RBX_ANIMSAVES`, importer `AnimSaves` under models, backup folders, clips of removed content, per-model `Animations` copies that the server strips anyway. Export to disk first (`SerializationService` to `.rbxm`; see [[Clip Archive Server]]).
2. **Thin keys.** Drop any key the joint's own interpolation reproduces within a tolerance. Tolerances used: 0.75 degrees and 0.03 studs for body joints when re-baking (0.5 degrees on hips), 0.03 degrees and 0.002 studs for lossless-looking buffer encoding. A joint that holds still gets no key at all.
3. **Drop placeholders nothing hangs from.** After thinning, prune weight-0 Poses with no weighted descendants, and drop keyframes left with only placeholders (keep the first, the last and any with markers).
4. **Sample secondary rigs sparser.** Hinge clips on weapons rarely need more than 5 to 8 keys per second.
5. **Stub clips.** Keep the `KeyframeSequence` (name, loop, priority, attributes, named and marker keyframes, first and last keyframes) but move the motion into a compact binary buffer stored as a base64 string attribute. A Lua player reads the buffer. See [[Baked Clip Stubs and Archiving]] and [[Clip Buffer Format]].
6. **Publish and remove sources.** A published clip costs nothing in the place. Keep sources on disk.

When NOT to stub: clips you will still edit in the Animation Editor this week (restore, edit, re-stub), and clips played by the real Animator through KSP registration in Studio tools (they need real Poses).

---

## 2. Clip data size on the wire

When clips are streamed rather than replicated as Instances, measure bytes:
- Enemy clips compiled to the buffer format (smallest-three quaternions, key thinning at 0.03 degrees): **19 to 235 KB per creature kit, about 1.6 MB for a full roster**. Each kit was sent once per client on a dedicated remote, then cached. The whole server-side build took 0.23 s.
- Until a kit arrived, the rig held a simple procedural pose, and boss intros "joined late" once data arrived. Boss kits were prefetched by zone.

Rules of thumb:
- Ship per area, not everything at join.
- Prefetch the next area's kits during travel.
- Keep the stream idempotent: a client that asks twice gets the same bytes and ignores the second copy.

---

## 3. Per-frame CPU

### The engine Animator
You do not control its cost directly, but you control how many tracks and rigs it has to evaluate:
- **Engine LOD** (Docs): `Animator.PreferLodEnabled` (default true) lets the engine lower evaluation frequency for remotely simulated characters based on distance, screen coverage and frame budget. `Workspace.ClientAnimatorThrottling` controls throttling for all Animators. `Animator.EvaluationThrottled` tells you a frame was skipped. Turn `PreferLodEnabled` off only for the few rigs that must be exact (a boss in a cutscene), never for crowds.
- **Track count.** Every playing track is part of the mix, including ones fading out (Docs: `GetPlayingAnimationTracks` lists them until their weight reaches zero). Whether a playing track held at weight 0 costs evaluation time is not documented; as a rule of thumb, stop layers you are not using rather than parking them at weight 0 forever.
- **Load once.** `LoadAnimation` creates a new track every call (Docs). The engine warns past 256 tracks on one Animator.

### Lua animation players
Measured costs in the reference project:
- A Lua keyframe player: **about 22 microseconds per 25-bone rig per frame**, 39 to 60 microseconds on the largest boss rig.
- Budget arithmetic: 40 rigs at full rate is about 0.9 ms per frame. With distance LOD (below), a typical fight with 15 nearby and 40 distant rigs costs well under 0.5 ms.

What keeps a Lua player that cheap:
- No allocation per frame: reuse accumulator tables (`table.clear`), no closures in the loop, no `Vector3`/`CFrame` churn you can avoid.
- Precompute per clip: rotation-vector pairs for every segment, the nlerp quaternion pairs, the "even spacing" flag. Sampling is then a binary search (cached segment index) and a lerp.
- Bind joints once per rig, rescan only when a joint is added or removed (listen to `DescendantAdded`/`DescendantRemoving` and set a dirty flag).
- One `PreSimulation` connection for all rigs, not one per rig.

See [[Lua Keyframe Player Internals]].

### Procedural motion and many parts
- **One loop for many objects.** A single `PreRender` or `PreSimulation` connection iterating a list is much cheaper than hundreds of connections.
- **`workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)`** moves many anchored parts in one call. Docs: use it when part movement is a confirmed bottleneck; `FireCFrameChanged` fires fewer `Changed` events than the default `FireAllEvents`. The reference project used it for foliage sway (at 30 Hz, only near the camera) and for floating arena pieces (quality-gated).
- **Update at a lower rate.** Ambient motion at 30 Hz or 20 Hz with interpolation is invisible to most players.
- **Sleep by distance.** Measured choices: NPC idles sleep beyond 280 studs; spinning world pieces animate within 900 studs (gates) or 280 to 650 (hub FX); bird flocks unparent beyond 900 studs; weapon-part rigs outside Workspace never update.
- **Pool effects.** Highlights are limited to 255 at once (Docs, October 2026; older docs said 31, and disabled Highlights still take a slot); the reference project pooled 8 white hit-flash Highlights with a 0.1 s fade and ran the fade loop only while one was live.

### Distance LOD
The single biggest runtime win. Two schedules used in production:

| Player | Full rate | Reduced | Further | Beyond |
|---|---|---|---|---|
| Character and enemy player | within 60 studs | every 2nd frame to 150 | every 4th frame to 300 | time only |
| Weapon-part rig player | own weapon, or within 40 studs | every 3rd frame to 120 | every 10th to 300 | every 30th |

Plus: off-screen rigs advance time only (checked every 3 frames); tiers are re-evaluated every 15 frames with a random phase so rigs do not all switch on the same frame. Details and pitfalls in [[Animation LOD]].

---

## 4. Tracks, connections and leaks

| Leak | How it happens | Fix |
|---|---|---|
| Track per use | `LoadAnimation` in an input handler | Cache per Animator; `GetTrackByAnimationId` |
| Marker connection per play | `GetMarkerReachedSignal(...):Connect` every time the move is used, never disconnected | Connect once per track and dispatch, or disconnect on `Stopped` |
| Tracks on dead characters | Cache keyed by character, never cleared | Weak-keyed cache or clear on `Destroying` |
| Animation objects created per call | `Instance.new("Animation")` each play | Create once per clip |
| Per-rig RunService connections | One connection per NPC that is never disconnected on despawn | One shared loop; remove from the list on despawn |
| Effect instances | Trails and particles cloned per hit and never destroyed | Pool, or `Debris:AddItem` with a short lifetime |

Measure with the Developer Console Memory tab: the `Animation` category (`Enum.DeveloperMemoryTag.Animation`, Docs) and `LuaHeap`. A rising `Animation` line while equipping and unequipping a weapon is a track leak.

---

## 5. Scripts and data limits

- **Script `Source` limit: 200,000 characters.** Saving fails with "Unable to assign property Source". Generated animation modules hit this: one swing module reached 195,812 characters and one kit's move module 192,059. Split into child ModuleScripts early. Keep a margin: a shared core of about 98k meant each kit's own code had to stay under about 95k.
- **200 locals per function scope.** Generated code with a local per clip fails to compile. Use tables.
- **Attributes as data carriers** work well for clip buffers (base64 strings), but very large strings make the Properties panel slow to open. Keep each under a few hundred KB.

---

## 6. Streaming

Animated content interacts with instance streaming:
- Rigs and their joints may arrive in pieces. Code that binds joints on `ChildAdded` of the model must handle late arrivals (the Lua player's dirty flag handles this).
- Streamed-out models destroy their tracks. Animation state must be reconstructible on stream-in from attributes and a start time (see [[Enemy Animation State Protocol]]).
- Workspace streaming properties are set in Studio's Properties panel; one project's tooling could not set them by script. Values chosen for a hub-and-realms world: StreamingMinRadius 256, StreamingTargetRadius 1024, StreamOutBehavior Opportunistic, ModelStreamingBehavior Improved, StreamingIntegrityMode MinimumRadiusPause. These are project choices, not recommendations for every game.
- Model `LevelOfDetail` (the far-away stand-in mesh) was set to Disabled on about 7,900 static map models in that project to stop distant geometry appearing; it does not affect animation, but disabling it on animated models avoids a frozen stand-in at range.

---

## 7. Studio and tooling health

- Keep offline tools offline. The reference project's rule after Studio froze for about 25 minutes at 100% CPU: at most 2 heavy baker processes per user of the machine, numeric libraries single-threaded, no background simulations inside Studio, and every Studio plugin call under 1.5 s.
- HttpService allows about 500 requests per minute per server. Tooling that posts per clip stalls; post per kit.
- Archive, do not keep, backup folders in the place.

---

## Checklist
- [ ] No `RBX_ANIMSAVES`, `AnimSaves` or backup clip folders shipped.
- [ ] Kit folders under budget (2,500 used); per-move instance counts known.
- [ ] Keys thinned; placeholders pruned; marker keyframes kept.
- [ ] Clips that are not edited this week are stubbed or published.
- [ ] Tracks cached per Animator; marker connections bounded.
- [ ] One shared update loop for Lua players and procedural motion.
- [ ] Distance and screen LOD on everything animated in Lua.
- [ ] Engine `PreferLodEnabled` left on except for a few hero rigs.
- [ ] Developer Console `Animation` memory flat across equip/unequip cycles.

## See also
[[Animation LOD]] · [[Baked Clip Stubs and Archiving]] · [[Clip Buffer Format]] · [[Case Study - Cutting a Million Instances]] · [[Lua Keyframe Player]] · [[Engine Gotchas]] · [[Troubleshooting Table]]

## Connected notes
<!-- auto-links:start -->
[[Authoring Clips in Code]] · [[Animation Data from Blender to Roblox]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Debugging Animation Problems]] · [[Case Study - Fast Join and Deferred Loading]] · [[Case Study - Instance Cleanup and Place Size]] · [[Animation Start Here]]
<!-- auto-links:end -->
