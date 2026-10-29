---
cssclasses: [vault-hub]
tags: [field-notes, hub, start-here, gotchas, production, lessons, type/hub, area/monetization, level/beginner]
---
# Field Notes Start Here

This section is a set of hard-won lessons from building a large Roblox action RPG over many months, much of it with many AI agents working in Studio at once. Each note is one specific trap: something that looked fine, shipped, and then broke in a way that took real time to understand. The topics are spread across the whole vault (camera, UI, input, animation, audio, networking, data, tooling), so read the note that matches your problem rather than the section front to back. Every note gives the cause, a fix with Luau where it helps, a "Common mistakes" table and a checklist.

Labels follow the vault: **Measured** means field-tested in the shipped reference game, **Roblox docs (as of October 2026)** means checked against the official reference, **Rule of thumb** means judgement.

## Read these first

The foundations these notes build on live elsewhere:

1. [[Frame Order and RunService Timing]]: when render steps, physics and animation run in a frame.
2. [[Input - UserInputService and ContextActionService]]: bindings, priorities and input states.
3. [[Client Prediction and Reconciliation for Combat]]: what the client may show before the server agrees.
4. [[DataStore Fundamentals]] and [[Session Locking and Profile Libraries]]: how player data is saved.
5. [[Multiple Agents in One Studio]] and [[Safety Rules for AI Agents in Studio]]: agents in a shared Studio.

## The notes in this section

**Camera and feel**
- [[Springs That Survive Long Frames - dt Clamps and NaN Guards]]: why Euler springs explode on hitches into a black screen, and a safe spring helper.
- [[Layering Camera Feedback on the Default Camera]]: roll and FOV punch after the camera step, without accumulating or fighting cutscenes.
- [[Client Hit Prediction for Melee Feedback]]: hit feel at the contact frame on the attacker's client, server echo suppressed per target.

**UI**
- [[UIStroke on Text - Glyph Counters and the Stroke Ratio]]: thick strokes fill the holes in 0, a and e; keep rounded fonts at or below about 7%.
- [[Shared Close Buttons and Headers Across Many Screens]]: one helper, X at 1.1 times the header height, clipping traps, undo attributes.
- [[Centre-Screen Announcements That Stay Centred]]: centre by scale, and one queued centre slot.

**Input**
- [[Hold-to-Attack Input That Never Sticks]]: held state from Begin and End, the same gates as a click, focus-loss resets.
- [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]]: remap every prompt off `ButtonX`, and rebind Tab if you hide the list.
- [[Shift-Lock Sprint and Gamepad B for Menus]]: Shift conflicts with mouse lock; bind B to close only while a panel is open.

**Animation and audio**
- [[Held Weapons on Motor6D - Locking the Grip During Attacks]]: no grip corrections during attack clips, one constant hold tilt.
- [[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]]: shortest-path angles, filled joint holes, swings not packed into two frames.
- [[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]: audit ids by real name, keep swells, cap overlaps, split loop layers.

**Luau**
- [[ipairs Stops at the First nil - Cleanup Tables That Leak]]: optional `nil` entries that leak looping sounds, and cleanup shapes that cannot skip.

**Players, joins and status**
- [[Streaming Joins - Frozen Players and Loading Screen Teardown]]: mid-air join poses are normal; loading screens need idempotent teardown and a watchdog.
- [[A Stuck Player Watchdog That Logs the Cause]]: detect, free the common causes, and log which one it was.
- [[Server-Authoritative Freeze and Stun Timestamps]]: `FrozenUntil` server-time attributes that expire on their own.
- [[Resetting One Player's Data Safely]]: every store and key, player offline first, `RemoveAsync`, receipts untouched.

**Studio and agents**
- [[Studio Automation Without Freezing Studio]]: backtracking patterns, chunking, the source size cap, compile checks, AutoRecovery.
- [[Moving Data Out of a Play Session]]: separate data models, a localhost bridge, chunked returns, baking runtime GUIs.
- [[Running Many AI Agents on One Roblox Place]]: ownership, claim files, fresh reads, disk backups, Play as a lock, edit markers.

## Quick rules from this section

- Clamp `dt`, sub-step springs at 1/120 s, and never write a non-finite CFrame.
- Camera effects bind at `Enum.RenderPriority.Camera.Value + 1` and replace, never add to, their own FOV.
- Predict hit *feel* locally; keep damage and numbers on the server.
- Every hold, lock or status has an end that does not depend on a message arriving.
- Never put a possibly-`nil` value in an array you will `ipairs`.
- Bulk Studio scripts: plain `find` before patterns, yield every ~50 ms, compile-check before writing.
- One owner per module; re-read before every edit; tag every edit.

## Connected notes
<!-- auto-links:start -->
[[Debugging Start Here]] · Game Feel Start Here · Post-Mortem - Building a Melee Action Game · Case Study - Building a Game with AI Agents · Melee Combat System End to End
<!-- auto-links:end -->
