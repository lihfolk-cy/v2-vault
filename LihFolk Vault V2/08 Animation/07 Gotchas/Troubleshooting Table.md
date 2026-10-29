---
tags: [gotchas, troubleshooting, reference, type/reference, area/animation, level/intermediate, api/Animator, api/IKControl, api/StepAnimations]
---
# Troubleshooting Table

Symptom first, then the likely cause, how to confirm it, and the fix. Rows are grouped by where the symptom shows up. When several causes are listed for one symptom, they are in order of how often they were the answer in the reference project (one live action game). For the reasoning behind each, see [[Engine Gotchas]]; for an unfamiliar symptom, follow [[Debugging Animation Problems]].

Shorthand: **KS** = KeyframeSequence, **KSP** = [[KeyframeSequenceProvider]], **GPAT** = `Animator:GetPlayingAnimationTracks()`.

---

## A. Nothing plays

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| A1 | Works in Studio, nothing on a live server | Id came from `RegisterKeyframeSequence` (Studio-only) | `track.Animation.AnimationId` is a hash or `active://` | Publish, or play the KS with a Lua player ([[Lua Keyframe Player]]) |
| A2 | Works in your place, not in the game | Asset owned by a different user or group than the experience | Client output shows a failed asset load | Re-upload under the experience owner ([[Animation Asset Permissions and Groups]]) |
| A3 | Nothing plays on a custom rig | No `Animator` under the Humanoid or AnimationController | `FindFirstChildOfClass("Animator")` is nil | Create the Animator on the server |
| A4 | `LoadAnimation` errors | Rig not under Workspace (or a WorldModel) | Error mentions the clip provider | Parent the rig to Workspace first |
| A5 | Some limbs never move | Pose names do not match `Part1` names on this rig | Compare the KS dump with the joint list | Rename parts or retarget the clip ([[Retargeting Animations Between Rigs]]) |
| A6 | Limb never moves, names match | That part has no joint (welded or unjointed) | No Motor6D/AnimationConstraint with that `Part1` | Add the joint; clip keys for missing joints are inert |
| A7 | Clip plays on R15, nothing on R6 (or reverse) | Clip authored for the other rig type | Pose names (`Torso` vs `UpperTorso`) | Author per rig type |
| A8 | `track.Length` stays 0 | Not loaded: wrong owner, deleted asset, Studio-only id live | `Length` after 3 s | See A1, A2 |
| A9 | Freshly registered KS plays nothing in Studio | Registration not loaded yet | `Length == 0` right after `LoadAnimation` | Wait for `Length > 0`, then play ([[Testing Animations in Studio]]) |
| A10 | Track exists, plays, rig does not move | Every key is on weight-0 placeholders, or the top-level root pose | KS dump shows no weighted poses below the root | Key child joints with weight 1 |
| A11 | Stubbed clip plays nothing in the real Animator | Stub has no Poses; data lives in an attribute | KS has only named/marker keyframes, no Poses | Play through the Lua player, or restore the original ([[Baked Clip Stubs and Archiving]]) |
| A12 | Nothing plays after many uses | 256-track warning: `LoadAnimation` per use | GPAT or output warning | Cache tracks per Animator |
| A13 | NPC animates for one player only | Played from a LocalScript | Other client and server see nothing | Play NPC tracks on the server, or drive every client from attributes ([[Enemy Animation State Protocol]]) |
| A14 | Character clip played by the server is jittery or missing for the owner | Owner's client also plays tracks and overrides | GPAT on the owner | Play character clips from the owning client |
| A15 | Plays in Play mode, nothing in Edit | Edit has no animation step and no physics | n/a | Use `StepAnimations` from the command bar or a plugin |
| A16 | Edit preview: `Transform` changes, parts do not move | `Transform` does not move parts without simulation | Parts' `CFrame` unchanged | Compute FK and pose anchored copies, or test in Play |
| A17 | Whole kit stops working after adding a clip | Clip name shadows a child the code looks up (`Origin`, `FX`) | Print `ClassName` of the found child | Rename the clip; keep clips in a subfolder |
| A18 | Weapon part clips never play live | Weapon rig clips registered via KSP | Same as A1 | Lua rig player or published `<Clip>Id` ([[Weapon Rig Player]]) |

## B. Plays, but late, cut short or overridden

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| B1 | First use seconds late, later uses fine | Asset loads on first play | `AnimationPlayed` log on time, `Length` 0 | Preload on equip with `ContentProvider:PreloadAsync`; load tracks early |
| B2 | Plays but a limb is held elsewhere | Higher-priority track keys that joint | Solo the track | Lower the other layer, or remove its keys on that joint |
| B3 | Right arm sticks straight out with a Tool | Default Animate `toolnone` hold | GPAT shows `toolnone` | Fade it to about 0 or replace its id ([[The Default Animate Script]]) |
| B4 | Attack plays but legs keep running | Attack clip does not key the legs (by design or by accident) | KS dump | Intended for upper-body moves; key legs if full-body |
| B5 | Pose is a mix of two clips | Same priority, weights averaged | GPAT shows both at one priority | Distinct priorities or a proper crossfade |
| B6 | Half-T-pose when a layer is at partial weight | Lowest layer blends toward rest | Nothing below keys the joint | Keep a full-weight base layer under partial layers |
| B7 | Clip restarts every frame, frozen at frame 0 | `Play` called every frame | `TimePosition` stuck near 0 | Call `Play` only on state change |
| B8 | Clip frozen mid-move | Hit-stop set speed 0 and never restored, or speed from `Length` 0 | `Speed` is 0 in GPAT | Token-based hit-stop restore; compute speed after load |
| B9 | Clip stops early without anyone calling Stop | Another system's "stop all tracks" helper | `Stopped` fires; search `:Stop(` | Stop by name or by owner only |
| B10 | Clip stops but keeps moving for a moment | `Stop` fade continues time | Expected (measured) | Use a shorter fade; do cleanup on `Ended` |
| B11 | Clip ends then slides back to idle | One-shot end holds then fades over 0.3 s (measured) | Last frame far from idle | End clips within about 75 degrees of the idle |
| B12 | Turning `Looped` off does nothing for a while | Applies at the next loop | Docs | `Stop` the track instead |
| B13 | Setting `TimePosition` is ignored | Set before `Play` | Docs | `Play` first, then set it |
| B14 | `AdjustWeight` after `Stop` does nothing | Docs: needs `Play` again | n/a | Use `AdjustWeight(0)` to hide, not `Stop` |
| B15 | Equip flourish cut instantly | A carry layer at Action2 or higher cancels it | Flourish cancel rule fires | Carry at Action; flourishes at Action2 |
| B16 | Speed fit to a window is wrong | `AdjustSpeed(Length / window)` while `Length` was 0 | Speed is 0 or inf | Wait for load first |
| B17 | Ability waits a beat before reacting | Code waits `task.wait(x)` instead of the marker | Timing log | Drive from `GetMarkerReachedSignal` |

## C. Wrong-looking motion

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| C1 | Joint spins the long way or flips | Key-to-key turn over about 120 degrees | KS dump angles | Add an in-between key (the reference pipeline caps segments at 120) |
| C2 | Joint randomly flips one way or the other | Exactly 180 degree key | Dump shows 180.0 | Split or offset by 0.5 degrees |
| C3 | Easing feels backwards | Legacy `Cubic` | Dump shows `Cubic` | Use `CubicV2` |
| C4 | Easing on the wrong span | Easing placed on the destination key | Dump | Easing belongs on the key that starts the span |
| C5 | Big turns differ from Blender or Moon previews | Animator blends rotation vectors, previews [[slerp]] | A/B diff | Smaller key gaps; predict with the Animator model |
| C6 | Constant key behaves unlike expected | Constant In/Out/InOut differ (measured) | Test each | Pick one direction and verify ([[Open Questions]]) |
| C7 | T-pose or rest flash mid-move | Identity keys written by a tool | Arm joints pass near 0 degrees between strong poses | Remove identity keys; QA "rest flash" |
| C8 | Pose pops when one clip hands to the next | Clip's last pose far from the next clip's first | Compare end/start poses | End near the idle (75 deg), start within 90 |
| C9 | Arms pass through the torso | Authored pose or solver chose an elbow inside the body | Filmstrip; arm QA | Re-solve with clearance ([[Pipeline - Arm IK Baking and QA]]) |
| C10 | Elbow flips between frames | Solver changed elbow swivel branch | QA "elbow swivel flip" over 30 deg/frame | Temporal smoothing (Viterbi) over the clip |
| C11 | Wrist snaps | Wrist turned over 30 degrees in one 60 Hz frame | QA metric | Spread over frames; let the arm aim the blade |
| C12 | Blade goes through the body | Long pommel or hand too close to the torso | Model the 20% of blade behind the grip | Keep the hand further out; push grips out of body boxes |
| C13 | Shoulder looks dislocated | Translation over 0.05 studs on an arm joint | Dump shows positions on arm poses | Arm keys rotation-only |
| C14 | "Chicken wing" elbow | Elbow raised high while hand hangs below | QA chicken-wing metric | Prefer elbow down/out/back ([[Elbow Poles Swivel and Joint Limits]]) |
| C15 | Hits feel weightless | Linear spans, no anticipation or settle | QA "linear spans" | Ease wind-ups In and strikes Out, add settle ([[Combat Animation Craft]]) |
| C16 | Motion is mushy at speed | Too few keys on a fast arc; rotation-vector chords cut corners | Hand path corners | Denser in-betweens on strikes (0.045 s spacing used) |
| C17 | Markers fire twice | Full-body and upper-body copy both playing | Two tracks in GPAT | Ignore upper-body duplicates in listeners |
| C18 | Marker never fires | Marker on a keyframe a tool dropped, or name typo | KS dump markers | Tools must keep marker keyframes; compare names exactly |
| C19 | Marker fires on the wrong machine | Listener only on one side | Log on owner and observer | Listen on every client that needs the FX |

## D. Feet, ground and scale

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| D1 | Feet slide while walking | Playback rate not matched to ground speed | Measure slip | `rate = speed / GroundSpeed`; per-clip GroundSpeed ([[Locomotion Systems]]) |
| D2 | Feet slide only at sprint | Rate clamp (1.5x) below what sprint needs | Speed / GroundSpeed exceeds the clamp | Separate run clip with a longer stride, or foot IK |
| D3 | Feet hover on a big character | Root offsets not scaled for body-scaled characters | `Model:GetScale()` is 1 | Store root offsets at game scale ([[Scale and Animation]]) |
| D4 | Feet sink on a scaled model | Clip already at game scale played on `ScaleTo` rig (double scale) | `GetScale()` not 1 | Author at scale 1 for model-scaled rigs |
| D5 | Feet through the floor in crouches | Root drop deeper than about 1 stud | Floor clearance check | Keep drops shallow (root y at least -1.0) or solve legs |
| D6 | Death pose sinks into slopes | Clip not ground-fitted | Lowest-part height per frame | Ground fitting plus a runtime clamp ([[Ground Fitting Pipeline]]) |
| D7 | Root motion ignored | Root keyed on the top-level root pose | Dump | Key the first child |
| D8 | Body plays turned 180 degrees from the root | Importer axis correction on the root pose | Head faces opposite LookVector | Axis fix ([[Enemy Import Axis Fix]]) |
| D9 | Root travel mirrored forward/back | Importer mirrored one axis on a rig | Compare with Blender | Flip that axis on the first child pose |
| D10 | Character slides during an attack | Movement speed not scaled during swings | Measure | Scale move speed during attacks (0.55 to 0.9 used) |
| D11 | Enemy walk looks frantic | Clip stride shorter than move speed implies | Stride vs def speed | Slow the move speed or re-author the walk; do not speed the clip |
| D12 | Big enemy walk looks floaty | Clip speed not adjusted for scale | n/a | Slow by about `0.85 / sqrt(scale)` (used in the reference project) |

## E. Procedural and IK

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| E1 | Procedural offset has no effect | Written in `PreRender`/`Heartbeat`, overwritten by the next animation step | Move the write | Write in `PreSimulation` |
| E2 | Procedural offset slowly winds up | `Transform = Transform * offset` on frames the Animator did not rewrite | Throttled Animator or unkeyed joint | Keep your own base; check `EvaluationThrottled` |
| E3 | Procedural joint snaps back to rest when a clip stops | Clip stopped writing; your code was relative to it | n/a | Blend your layer explicitly |
| E4 | Head turns the wrong way | Rig's C0 axes differ from assumed | Flip a sign and test | Derive axes from the joint frame |
| E5 | IK hand lags a frame behind the body | Reading `Part.CFrame` in `PreSimulation` (still last frame's) | Compare with FK | Compute the parent chain by FK from the root |
| E6 | IK elbow inverts | Hinge sign or pole wrong | Elbow bends backwards | Fix hinge axis sign per limb ([[Two-Bone IK Math]]) |
| E7 | IK snaps at full reach | Target past chain length | Distance > upper + lower | Clamp reach slightly short of straight |
| E8 | [[IKControl]] does nothing | Missing ChainRoot/EndEffector/Target/Type, or not under Humanoid/AnimationController with Animator | Check properties | Set all four ([[IKControl Reference]]) |
| E9 | IKControl at weight 0 still affects the pose | SmoothTime/Pole still apply (Docs) | n/a | Use `Enabled = false` |
| E10 | Accessory does not follow a procedural head | Accessory part not welded | n/a | Weld it to the head |

## F. Replication and multiplayer

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| F1 | Others do not see my Lua-driven animation | Script writes do not replicate | Second client | Relay state; every client runs the same player |
| F2 | Late joiner sees enemies in T-pose or wrong clip | State was only an event | Join mid-fight | Attributes with clip name plus server start time |
| F3 | Late joiner sees a one-shot from its start | Start offset ignored | n/a | Start at `(GetServerTimeNow() - t0) * speed` |
| F4 | Others see my flourish at the wrong time | Relay without timestamps | Compare clocks | Send start time, not "play now" |
| F5 | Server hit lands before the visual | Server uses marker time without latency allowance | Log | Server hit at marker minus a small lead (0.06 s used) and telegraphs at least 0.4 s |
| F6 | Others see the weapon in the wrong hand pose | Grip offsets computed only on the owner | Second client | Compute grip from shared data on every client |

## G. Performance

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| G1 | Long join times | Hundreds of thousands of Pose instances in ReplicatedStorage | Count descendants | Thin, stub, publish ([[Performance and Memory]]) |
| G2 | Studio slows to 15 fps | Place over about 1M instances (measured) | Instance count | Archive importer saves and backups out of the place |
| G3 | Frame spikes with many NPCs | Every rig updates every frame | MicroProfiler | Distance and screen LOD ([[Animation LOD]]) |
| G4 | Memory grows each equip | Tracks loaded per equip, connections never disconnected | Dev Console `Animation` memory | Cache tracks; disconnect on unequip |
| G5 | Script will not save | `Source` over 200,000 characters | Error "Unable to assign property Source" | Split into child modules |
| G6 | Hit flashes stop appearing | Over the Highlight limit (255 now, 31 in older docs) | Count | Pool Highlights (cap at 8 used) |
| G7 | Far enemies' markers stop firing | LOD stopped advancing time | n/a | Always advance time and fire events; skip only writes |

## H. Tooling and Studio

| # | Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|---|
| H1 | Edited module behaves like the old version | `require` cache in Studio plugin context | Add a print | Clone the ModuleScript, require the clone, destroy it |
| H2 | Requiring a destroyed clone hangs | Module uses `WaitForChild` on children that went away | n/a | Require before destroying, or avoid `WaitForChild` in tool modules |
| H3 | Test rig from `CreateHumanoidModelFromDescription` will not animate in Edit | No Motor6Ds (measured) | Joint list empty | Build joints from RigAttachment pairs |
| H4 | `StepAnimations` errors in a script | Plugin-only security | Docs | Run it from the command bar or a plugin |
| H5 | `StepAnimations(0)` does not advance | `dt` must be > 0 (measured) | n/a | Step with `1/60` |
| H6 | Camera stuck after a scripted capture | `CameraType` left `Scriptable` | n/a | Set `Custom` after captures |
| H7 | Imported model not found | Several imports all named `Scene` | n/a | Find by content (a uniquely named part) |
| H8 | Baking tool refuses to install | Source clip changed since it was dumped (fingerprint) | Tool says REFUSED | Re-dump, re-bake |
| H9 | Re-baked clip got worse | Baked a baked clip | `ProBaked` attribute present | Rebuild from the safety copy |
| H10 | A/B test shows the Animator "off" on one clip | Clip is a stub (A/B falls back to Lua) | Stub check | Restore originals before A/B |

---

That is 99 rows. If a symptom is not here, it is probably in the craft category (the data is valid but the motion is poor); see [[Animation Quality Standard]] and [[Animation Review Checklist]].

## See also
[[Engine Gotchas]] · [[Debugging Animation Problems]] · [[Testing Animations in Studio]] · [[Performance and Memory]] · [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Snippets - IK]] · [[Animation Glossary]] · [[Playback, Priorities and Blending]] · [[Inverse Kinematics]] · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Authoring Clips in Code]] · [[Animator Deep Dive]] · [[Snippets - Lua Keyframe Player Core]] · [[How the Animator Really Behaves]] · [[Snippets - Playing Animations]] · [[Procedural Animation]] · [[AnimationTrack Reference]] · [[KeyframeSequence Keyframe and Pose Reference]]
<!-- related:end -->
