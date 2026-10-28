---
cssclasses: [vault-hub]
tags: [2d, 2.5d, hub, side-scroller, platformer, pixel-art, screengui, sprites, tilemap, multiplayer]
---
# 2D Game Development Start Here

Roblox is a 3D engine, but people make good 2D games on it all the time: platformers, shmups, puzzle games, rhythm games, card battlers, side-scrolling brawlers, retro arcade minigames inside bigger experiences. There are two ways to do it, and they share almost nothing below the surface:

- **GUI 2D.** The playfield is a `ScreenGui`. Every sprite is an `ImageLabel`, the world is a table of numbers, and you write the loop, the physics, the camera and the netcode yourself. You get pixel-exact control and crisp art, and you give up everything the engine does for 3D worlds.
- **Locked-camera 2.5D.** The world is an ordinary 3D place. A side camera and a few constraints keep everything on one plane. You keep Humanoids, physics, replication, lighting, avatars and Studio's level tools, and you spend your effort stopping the third dimension from leaking back in.

This section is nine notes that cover both routes from the first decision to a multiplayer game. Every note has working `--!strict` Luau, the numbers that matter, failure modes, and a checklist. This hub tells you what each note is for, the order to read them in, the numbers worth remembering, and where the older notes in the vault fit.

Source labels used across the section: **Roblox docs (as of October 2026)** for anything taken from create.roblox.com, **rule of thumb** for experience-based guidance, and **unverified** where the docs were silent. Roblox changes fast; re-check limits that matter to you.

---

## The nine notes

| Note | Route | What it gives you |
|---|---|---|
| [[Choosing GUI 2D or Locked-Camera 2.5D]] | Both | The decision: the one multiplayer question that settles most projects, a side-by-side comparison, what each route cannot do well, security differences, the screen-size tax of GUI games, worked decisions |
| [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] | GUI | The engine skeleton: fixed-timestep loop with interpolation, entities as plain data, pooled and dirty-checked `ImageLabel` rendering, layers, culling, pixel snapping, a basic camera, lifecycle |
| [[Sprite Sheets and Frame Animation with ImageRectOffset]] | GUI | Atlases and `ImageRectOffset`/`ImageRectSize`, padding and bleeding, mirroring, a sprite registry, importing frame data from art tools, a frame-accurate animation player, gameplay events on frames |
| [[2D Collision Physics and Platformer Movement]] | GUI (tuning applies to both) | Tile collision with separate axes, integer movement with remainders, one-way platforms, jump tuning from height and time, coyote time and buffering, slopes, moving platforms, headless tests |
| [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] | Both | Where blur comes from and how to remove it: `ResampleMode` Pixelated, integer scaling, atlas packing with extrusion, texture size limits, uploading and moderation, palette swaps, pixel art on 3D surfaces |
| [[EditableImage for Pixel Buffers and Procedural 2D]] | GUI mostly | The current `EditableImage` API, memory budgets and permissions, a framebuffer with dirty rectangles, destructible terrain, fog of war, procedural effects, fallbacks for when creation fails |
| [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]] | 2.5D | The three locks (camera, input, body), `PlaneConstraint` on characters, low field of view instead of orthographic, input remapping, a complete setup, level building and multiplayer on a plane |
| [[Tilemaps Cameras and Parallax for 2D Levels]] | Both | Level data with separate collision and visual layers, Tiled import and flip flags, chunked tile rendering, seams, camera regions and room cameras, parallax with tiled `ImageLabel`s, greedy-merged parts for 2.5D |
| [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] | GUI (ideas apply to both) | Three network architectures, a deterministic shared simulation, buffer-packed inputs and snapshots under the remote limits, snapshot interpolation, prediction and reconciliation, replay validation |

---

## How to read the section

### Step zero: decide the route

Read [[Choosing GUI 2D or Locked-Camera 2.5D]] before writing anything. The cost of choosing wrong is a rewrite, not a refactor. The short version of its advice:

- Other players visible and moving in real time, or avatars matter to the design: lean **2.5D**.
- Single player, pixel-perfect art, puzzle or rhythm or card mechanics, or a minigame inside a 3D game: lean **GUI 2D**.
- Competitive and real-time and pixel art: possible in GUI 2D, but you are signing up for everything in [[2D Multiplayer - Server Authority and Replicating GUI Worlds]]. Budget for it honestly.

### Path A: a GUI platformer or arcade game

1. [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]: build the loop, world and renderer first, with coloured boxes instead of art.
2. [[2D Collision Physics and Platformer Movement]]: make a box run and jump on a tile grid until it feels good. Do not draw anything nice until this step feels right; art hides bad movement only until someone plays.
3. [[Tilemaps Cameras and Parallax for 2D Levels]]: load real levels from an editor, add the camera rules, add parallax.
4. [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]] and [[Sprite Sheets and Frame Animation with ImageRectOffset]]: bring in the art and animation.
5. [[EditableImage for Pixel Buffers and Procedural 2D]]: only if the design needs pixels you cannot get from sprites (destructible terrain, painting, fog of war).
6. [[2D Multiplayer - Server Authority and Replicating GUI Worlds]]: if anything valuable comes out of the game, at least the summary or replay validation sections, even for single player.

### Path B: a 2.5D side-scroller

1. [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]: camera, input and body locks, the complete setup.
2. [[2D Collision Physics and Platformer Movement]], section on the same tuning in 2.5D: the jump-from-height maths applies to Humanoids and custom controllers alike.
3. [[Tilemaps Cameras and Parallax for 2D Levels]]: the camera region ideas, parallax with a flattened camera, and building levels from tile data with greedy merged parts.
4. [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]], the section on pixel art on 3D surfaces, if you want a pixel look in 3D.
5. Networking is mostly the engine's job; read the multiplayer section of the side-scroller note and the general networking notes listed below.

### Path C: a 2D minigame inside a 3D experience

Arcade cabinets, hacking puzzles, fishing or lockpicking minigames. Read the engine note for the loop and renderer, the collision note only if the minigame moves things, and the pixel art note for the art. Three warnings specific to this case: set `ResetOnSpawn = false` on the minigame's `ScreenGui` or a character reset deletes it mid-game; pause or stop the loop when the minigame closes, because a hidden loop still runs; and validate whatever reward the minigame grants on the server (the security section of the choosing note).

---

## Numbers worth remembering

These are collected from the notes, with the label each one carries there.

| Topic | Number | Label |
|---|---|---|
| Simulation rate | 60 Hz fixed step, at most about 5 catch-up steps per frame | rule of thumb |
| Step budget | Under about 1 ms per step on a mid phone, so 4 catch-up steps fit a 33 ms frame | rule of thumb |
| GUI objects changing every frame | Under 200 comfortable, 200 to 600 fine with pooling and dirty checks, over 1,000 risky on a mid phone | rule of thumb |
| Visible tiles | 320 by 180 view with 16 pixel tiles shows up to 21 by 13 = 273 tiles per layer | arithmetic |
| Sprite sheets and atlases | Keep each at or below 1024 by 1024, uploaded at native size, cells padded and extruded | rule of thumb from the texture docs |
| EditableImage | Maximum 1024 by 1024, 4 bytes per pixel, so 4 MB for a full image; device specific client memory budget; mesh and image APIs must be enabled for published games | Roblox docs (as of October 2026) |
| Field of view for 2.5D | `FieldOfView` is clamped 1 to 120 degrees; there is no orthographic camera | Roblox docs (as of October 2026) |
| Unreliable remote payload | Dropped above 1,000 bytes (older docs said 900; design for 900) | Roblox docs (as of October 2026) |
| Remote rate | About 500 requests per second per client, shared by all remotes of the same type | Roblox docs (as of October 2026) |
| Snapshot rate and delay | 20 snapshots per second, remote players drawn about 100 ms behind server time | rule of thumb |
| Snapshot entity budget | 13 byte header plus 9 bytes per entity: about 98 entities per 900 byte packet | arithmetic from the packet layout |

If you need a number that is not in this table, it is probably not documented. Measure it in your game with the [[MicroProfiler Guide]] and [[Developer Console and Stats]], and write the result down where your team can see it.

---

## Conventions used across the section

The notes were written to fit together, so their code agrees on a few conventions. Keep them if you combine the snippets:

- **World units are logical pixels**, X right and Y down, the same as GUI offsets. The 2.5D notes use studs and Y up, and convert at one place when building from tile data.
- **The simulation never touches Instances.** Entities, tiles and collision are tables or buffers. The renderer reads them and writes GUI properties. This is what makes headless tests, server validation and replays possible.
- **Snap at render time only**, camera first, then everything derived from the snapped camera. Screen shake is added after snapping, in whole pixels.
- **`ResampleMode = Enum.ResamplerMode.Pixelated`** on every pixel-art image, and an integer world scale with letterboxing for the rest of the screen.
- **Collision data is separate from visual data**, in tilemaps and in sprites (hitboxes come from frame data, not image bounds).
- **The client is never trusted** for anything that grants value, in either route.

---

## Mistakes that cut across every note

These come up in nearly every 2D project on Roblox, whichever route it took:

- **Starting with art.** The prettiest prototype with floaty movement loses to a grey box that feels great. Movement and camera first.
- **Variable time step.** Physics that depends on frame rate behaves differently on a 30 fps phone and a 144 Hz monitor. Use the fixed step from the engine note, or in 2.5D let the physics engine own movement.
- **Blur accepted as normal.** Blurry pixel art is always a fixable cause: resampling, non-integer scale, sub-pixel position, or downsampling. The pixel art note walks the list.
- **Testing on one screen.** GUI 2D games break on aspect ratios and safe areas you did not test. Check a phone in portrait and landscape, a tablet, and an ultrawide monitor ([[Responsive UI for Phone Tablet Console and PC]], [[Safe Areas and Insets]]).
- **Multiplayer added late.** A single-player GUI engine cannot be made multiplayer by adding remotes; the simulation has to be deterministic and server runnable from the start. Decide early.
- **Forgetting the avatar.** Roblox players expect to see themselves. A GUI 2D game should at least show the player's avatar somewhere (a portrait, a lobby, a results screen), which the choosing note discusses as a retention cost.

---

## Related notes elsewhere in the vault

Design and level craft:

- [[Genre Playbook - Obbies and Platformers]]: what platformer players on Roblox expect, and how the genre retains them.
- [[Obby and Platforming Level Design]]: jump gaps, rhythm, checkpoints and difficulty curves; feed it the jump numbers from the collision note.
- [[Level Design Principles - Flow Sightlines and Landmarks]] and [[Level Design for Roblox]]: general layout craft that applies to side views too.
- [[Input Responsiveness Buffering and Coyote Time]] and [[Hit-Stop and Screen Shake Tuning by Numbers]]: the feel layer on top of the movement code.
- [[Motion Sensitivity and Camera Comfort]]: comfort settings for shake, parallax and camera follow.

UI and rendering foundations for the GUI route:

- [[ScreenGui Fundamentals]], [[Layout - Scale Offset and Constraints]], [[Responsive UI for Phone Tablet Console and PC]], [[Safe Areas and Insets]].
- [[UI and GUI Animation]] for menus and HUD motion around the playfield.
- [[Textures Decals and Texture Memory]], [[Rendering Performance]], [[Mobile and Low-End Optimization]].

Engine and code:

- [[Frame Order and RunService Timing]] for when `PreRender`, `PreSimulation` and `Heartbeat` fire.
- [[Intersection and Collision Math]] for swept tests and spatial hashing beyond tiles.
- [[Springs Damping and Smoothing]] for frame-rate independent camera smoothing.
- [[Custom Character Controllers]] and [[Mover Constraints and Physics Controllers]] for the 2.5D body.
- [[Camera Systems]] for camera scripting in general.
- [[Buffers and Binary Data]] and [[Luau Performance and Native Codegen]] for compact data and fast simulation code.
- [[Seeds Determinism and Reproducible Worlds]] and [[Procedural World Generation]] for generated levels.

Networking and security:

- [[Replication Rules]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Server Authority and Validation]].
- [[Client Prediction and Reconciliation for Combat]] and [[Interest Management and Per-Player Replication]] for the deeper theory behind the multiplayer note.
- [[Remote Abuse Patterns and Rate Limiting in Practice]] and [[Exploits and Anti-Cheat]].
- [[Network Bandwidth Budgets and Measuring Them]] to check your snapshot sizes against reality.

Art pipeline:

- [[UI Asset Pipeline]], [[Art Pipeline - Concept to In-Game Asset]] and [[Asset Upload Automation with Open Cloud]] for getting sheets into the game repeatably.
- [[Principles of Animation for Games]] for the drawing side of frame animation.

---

## A first project, scoped

If you have never shipped a 2D game on Roblox, a scope that teaches every part of this section without drowning you (rule of thumb from small team projects):

1. **Week 1:** GUI engine with boxes, fixed step, one test level written as row strings, run and jump tuned until it feels good. Headless test that the player can finish the level.
2. **Week 2:** Tiled import, chunk renderer, camera with dead zone and regions, one parallax layer. Three short levels.
3. **Week 3:** Pixel art for the player and one tileset, sprite registry, run, jump and fall animations, a hurt flash. Test on a phone.
4. **Week 4:** Hazards, one enemy type, checkpoints saved by id, a results screen that shows the player's avatar, and summary validation of the finish time on the server.

Only after that, decide whether the game needs multiplayer, and if it does, read the multiplayer note end to end before writing any networking code. Scope advice in general is in [[Planning and Scoping a Roblox Game]].

---

## Checklist before you start building

- [ ] Route chosen with the choosing note, and the reason written down.
- [ ] Multiplayer decided now, not later; architecture picked if yes.
- [ ] Logical resolution and tile size picked; integer scale plan for every screen.
- [ ] Engine conventions adopted (logical pixels, Y down, simulation in tables, snap at render).
- [ ] Movement prototyped and tuned before final art.
- [ ] Level format and editor picked; tile ids append-only.
- [ ] Art pipeline tested once end to end: draw, export, pack, upload, display crisp on a phone.
- [ ] Server validation planned for anything that grants value.
- [ ] A test device list: one low-end phone, one tablet, one PC, one ultrawide.

## Connected notes
<!-- auto-links:start -->
[[Input Buffering]] · [[Resource Library - Networking and Multiplayer]] · [[Deterministic Simulation]] · [[Game Feel Start Here]] · [[Voxel Modelling Start Here]] · [[Modelling to the Roblox Camera and Player Scale]]
<!-- auto-links:end -->
