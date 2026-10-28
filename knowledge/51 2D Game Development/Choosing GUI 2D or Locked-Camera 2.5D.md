---
tags: [2d, game-design, architecture, screengui, camera, side-scroller, decision, luau]
---
# Choosing GUI 2D or Locked-Camera 2.5D

Roblox is a 3D engine with a strong 2D UI system bolted on. That gives you two honest ways to build a 2D game, and one hybrid that is often the right answer:

1. **GUI 2D**: the playfield is a `Frame` inside a `ScreenGui`. Every sprite is an `ImageLabel`, every tile is a `Frame` or an `ImageLabel`, and your own Luau code does movement, collision and rendering.
2. **Locked-camera 2.5D**: the world is ordinary 3D parts and characters, the camera looks at it from the side (or from above), and movement is held to a plane. The engine does physics, replication, lighting and avatars; you take away one axis.
3. **Hybrid**: a 2.5D world for the game, plus GUI layers for HUD, menus and the occasional fully 2D minigame (an arcade cabinet, a hacking puzzle, a fishing bar).

This note is the decision. It compares the two on the things that actually decide projects (multiplayer, avatars, input, art pipeline, performance on phones, effort), lists the failure modes that only show up weeks in, and ends with a checklist. The implementation notes are linked at each step: [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] for the GUI route, [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]] for the 2.5D route.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (one production 3D game whose UI lessons carry over), and **rule of thumb**.

---

## 1. The one question that decides most projects

Before any comparison table, ask: **does the game need other players to be visible in the world, moving in real time?**

- If **yes** (a co-op platformer, a 2D battle arena, a side-scrolling hangout), lean hard toward **2.5D**. In 3D, character replication, network ownership, interpolation and collision between players are already done by the engine. In GUI 2D, none of that exists: a `Frame` you move on one client does not move on any other client, because the client created it and the server never knew about it. You would be writing your own netcode for every moving thing. See [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] for what that costs.
- If **no** (a single-player puzzle game, a rhythm game, a card battler, a shmup where others are only on a leaderboard), **GUI 2D** becomes attractive, because you get pixel-exact control, crisp art and a world that costs almost nothing to replicate.

Roblox players also expect to see their avatar. A GUI 2D game hides the avatar the player paid for. That is not a technical problem, but it is a real retention and social cost on this platform (rule of thumb from the genre: games that show avatars get more screenshots, more "join my friend" moments and more cosmetic sales). If your design depends on avatars, 2.5D is close to mandatory.

---

## 2. Side-by-side comparison

| Concern | GUI 2D (ScreenGui playfield) | Locked-camera 2.5D (3D world) |
|---|---|---|
| Physics and collision | You write it: AABB tests, gravity, slopes, one-way platforms ([[2D Collision Physics and Platformer Movement]]) | Engine physics; you constrain one axis |
| Multiplayer replication | None. You replicate state yourself with remotes | Automatic for parts and characters |
| Avatars | Not shown unless you render them in a `ViewportFrame` (costly, see section 5) | Shown for free, with animations |
| Pixel-perfect art | Yes: `ResampleMode = Pixelated`, integer scaling, exact positions | Hard: perspective, lighting, mip-mapping and filtering soften pixels |
| Lighting, shadows, particles | No engine lighting; `ParticleEmitter` does not render in GUI; you fake effects with images and tweens | Full lighting, particles, beams, post-processing |
| Determinism | Fully under your control (fixed timestep, your own integrator) | Engine physics is not deterministic across machines |
| Exploit surface | Client runs the whole game; the server must check results, not trust them | Same client-trust problem for characters, but the engine already limits a few things |
| Screen sizes | You must handle aspect ratio and safe areas yourself | The camera handles aspect ratio; only the HUD needs care |
| Level editing | No built-in editor: you need a tile editor, data format and loader ([[Tilemaps Cameras and Parallax for 2D Levels]]) | Build levels in Studio with parts, as usual |
| Performance on phones | Cheap if you cull and pool; expensive if you create and destroy GuiObjects every frame | Normal 3D costs; usually lighter than a full 3D game because the view is narrow |
| Code you own | Everything: loop, render, input, physics, camera | Camera lock, input remap, plane constraint, level streaming |
| Typical effort to a playable prototype (rule of thumb) | 1 to 3 weeks for a solid platformer core | 2 to 5 days |

Read the last row carefully. A GUI 2D game looks simpler because it is "just frames", but you are writing a small engine. The 2.5D route borrows a finished engine and removes features. Teams consistently underestimate the first and overestimate the second (rule of thumb).

---

## 3. When GUI 2D is clearly right

- **Pixel art is the identity of the game.** Crisp, unfiltered pixels at an integer scale are straightforward in GUI with `ImageLabel.ResampleMode = Enum.ResamplerMode.Pixelated` (Roblox docs (as of October 2026): "When set to Enum.ResamplerMode.Pixelated, the image preserves the sharp edges of pixels"). In 3D, the same art goes through lighting, perspective and texture filtering, and keeping it crisp is a fight. The pipeline is in [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]].
- **Gameplay needs exact, frame-stable rules.** Rhythm games, fighting-game style hitboxes, bullet patterns and puzzle games that must behave identically every run. Your own fixed-timestep loop gives you that; the physics engine does not.
- **The 2D game lives inside a 3D game.** A minigame on an arcade cabinet (a `SurfaceGui` on a part), a lockpicking bar, a fishing reel, a phone app inside the game. These are small, single-player, and short. GUI 2D is the natural fit, and the 3D game around it supplies the social layer.
- **Turn-based or low-motion games.** Card games, board games, tactics grids. Very few objects move each frame, replication is just "state changed", and GUI layout objects (grids, lists) do half the work. See [[UI Layout Objects - Lists Grids and Pages]].

## 4. When 2.5D is clearly right

- **Multiplayer action**: co-op platformers, side-scrolling brawlers, 2D-view battle games. Replication is the expensive part of a game, and 2.5D gets it for free.
- **Avatars matter**: hangouts, roleplay, cosmetic-driven games.
- **You want engine effects**: lighting moods, particles, explosions, physics props that tumble, ragdolls.
- **The team builds in Studio**: level designers who place parts get to keep their workflow ([[Obby and Platforming Level Design]] applies almost unchanged).
- **Platformers with physics toys**: swinging ropes, seesaws, rolling boulders. `HingeConstraint`, `RopeConstraint` and friends work as normal; in GUI 2D each of these is a mini physics project.

The mechanics of holding a 3D world to a plane are in [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]. In short, as of October 2026 the docs list a `PlaneConstraint` (Roblox docs: it "moves its Attachment0 and Attachment1 into a position/orientation along a plane whose normal vector is the primary axis of Attachment0"), while the older `Plane` class is marked deprecated. Many games instead clamp the root position each frame or remap input so the character never gets a depth component; the trade-offs are in that note.

---

## 5. The awkward middle: what each route cannot do well

### GUI 2D weaknesses

- **No particles.** `ParticleEmitter` needs a 3D parent. You fake particles with pooled `ImageLabel`s or `Frame`s and your own update loop. A budget of 100 to 300 live GUI particles is comfortable on mid phones; thousands is not (rule of thumb; measure with [[MicroProfiler Guide]]).
- **No rotation clipping by default.** Roblox docs (as of October 2026): `GuiObject.Rotation` "is not compatible with ClipsDescendants", and when `StarterGui.ClipsDescendantsSupportsRotation` is off, any rotated ancestor makes `ClipsDescendants` be ignored. With that setting on, rotated children clip correctly, but "clipping by rotated shapes (when the clipping parent itself is rotated) or by rounded corners is not supported". So a rotating sprite near the edge of the playfield can draw outside it, and a rotated playfield (a tilted screen-shake) stops clipping. Design screen shake as translation only, or put a mask frame on top.
- **Rotation pivot is fixed.** Docs: rotation "is relative to the center of the object, not the AnchorPoint, meaning you cannot change the point of rotation." Rotating a sword sprite around its hilt needs a parent frame centred on the hilt.
- **Avatars cost a lot.** You can show a character in a `ViewportFrame`, but each viewport is a separate small 3D render; a few are fine, dozens are not. A common compromise is a static avatar headshot (a thumbnail image) on the HUD and a sprite character in the world.
- **Everything is client-side.** The server cannot see the world. Score, currency and progression must be validated: see [[Server Authority and Validation]] and section 6.

### 2.5D weaknesses

- **Pixel crispness.** Textures on parts are filtered and mip-mapped. Pixel art on a `SurfaceGui` with a pixelated `ImageLabel` keeps edges sharper, but lighting and perspective still change it. If the look must be exact, that is a vote for GUI.
- **Depth leaks.** Physics pushes, explosions, collisions with slanted parts and other players can all nudge a character off the plane. You must correct every frame, server-side for anything authoritative.
- **Perspective.** A perspective camera makes near objects larger and shows the sides of blocks. A low field of view from far away approximates an orthographic look. Roblox docs (as of October 2026): `Camera.FieldOfView` "is clamped between 1 and 120 degrees and defaults at 70". There is no true orthographic camera in the docs as of October 2026 (I could not find one), so a 2.5D game picks a compromise: FOV around 20 to 40 with the camera pulled far back (rule of thumb), at the cost of depth-sorting artefacts at very low FOVs and a camera that must sit far away.
- **Default controls.** The default character controller and camera assume 3D. Touch thumbsticks, shift lock and camera zoom all need to be replaced or turned off.

---

## 6. Security differs more than people expect

In both routes the client is untrusted ([[Exploits and Anti-Cheat]]). The difference is how much of the game the server can see.

- In 2.5D the server owns the world, sees character positions (with network ownership caveats from [[Network Ownership]]), and can run sanity checks on speed and position as in any 3D game.
- In GUI 2D the server sees **nothing** unless you send it. A cheater can edit the client to make the player invincible, teleport to the goal, or report a perfect score. The honest options are:
  - **Do not care** for single-player cosmetics and personal-best runs that grant nothing tradeable.
  - **Validate summaries**: the client sends "level 4 finished in 38.2 s, 3 coins collected". The server checks that level 4 is unlocked, that 38.2 s is above the possible minimum, and that 3 is at most the coin count of level 4, and that the elapsed server time since the level started is at least 38.2 s.
  - **Replay check**: the client sends its input log; the server reruns your deterministic simulation (same fixed timestep, same code in a shared ModuleScript) and compares. This is strong but costs server CPU and requires a truly deterministic engine. See [[2D Multiplayer - Server Authority and Replicating GUI Worlds]].
  - **Run it on the server**: for competitive multiplayer, the server simulates and the clients only render. Then GUI 2D is just a renderer, and you have built 2.5D-style authority by hand.

If anything valuable (currency, leaderboard rank, tradeable items) comes out of a GUI 2D game, budget for at least summary validation from day one.

---

## 7. Screen size: the GUI route's hidden tax

A 3D camera adapts to any aspect ratio automatically. A GUI playfield does not. Phones run from about 16:9 to 20:9 and wider, tablets are near 4:3, and safe areas cut into the edges ([[Safe Areas and Insets]]). Choose a policy up front:

| Policy | How it looks | Good for |
|---|---|---|
| Fixed logical resolution, letterboxed | A 16:9 (or 4:3) box with bars on the sides or top | Puzzle, rhythm, pixel art at integer scale |
| Fixed height, variable width | Wider screens see more of the level horizontally | Side-scrollers (more look-ahead on wide phones, a slight competitive edge) |
| Fixed width, variable height | Taller screens see more vertically | Vertical shmups, tower climbers |
| Stretch | Distorted | Never for a game world |

The pattern used by most GUI 2D games is a **logical resolution** (for example 320 x 180 or 480 x 270 "game pixels") drawn inside a frame that is scaled by an integer factor to fit the screen. Integer scaling keeps pixel art crisp; non-integer scaling makes some pixels one screen pixel wider than others (visible shimmer as sprites move). The core of that setup:

```lua
--!strict
-- Letterboxed integer-scaled playfield for a GUI 2D game.
-- Put in a LocalScript under StarterPlayerScripts.
local Players = game:GetService("Players")

local LOGICAL_W = 320
local LOGICAL_H = 180

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screen = Instance.new("ScreenGui")
screen.Name = "Game2D"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local bars = Instance.new("Frame")
bars.Name = "Letterbox"
bars.Size = UDim2.fromScale(1, 1)
bars.BackgroundColor3 = Color3.new(0, 0, 0)
bars.BorderSizePixel = 0
bars.Parent = screen

local playfield = Instance.new("Frame")
playfield.Name = "Playfield"
playfield.AnchorPoint = Vector2.new(0.5, 0.5)
playfield.Position = UDim2.fromScale(0.5, 0.5)
playfield.BackgroundColor3 = Color3.fromRGB(24, 20, 37)
playfield.BorderSizePixel = 0
playfield.ClipsDescendants = true
playfield.Parent = bars

-- The world is authored in logical pixels inside this frame.
local world = Instance.new("Frame")
world.Name = "World"
world.Size = UDim2.fromOffset(LOGICAL_W, LOGICAL_H)
world.BackgroundTransparency = 1
world.Parent = playfield

local uiScale = Instance.new("UIScale")
uiScale.Parent = world

local function refit()
	local avail = bars.AbsoluteSize
	-- Largest whole-number scale that fits; never below 1.
	local s = math.max(1, math.floor(math.min(avail.X / LOGICAL_W, avail.Y / LOGICAL_H)))
	uiScale.Scale = s
	playfield.Size = UDim2.fromOffset(LOGICAL_W * s, LOGICAL_H * s)
end

bars:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
refit()
```

Two nuances. First, on small phones the integer scale may leave a large unused border (a 320 x 180 world on an 844 x 390 safe area fits at scale 2, using 640 x 360 and leaving bars). If that waste is unacceptable, either pick a logical size that divides common screens better, or allow fractional scale and accept slight shimmer, or snap only sprites (not the world) to whole screen pixels. Second, `UIScale` scales everything under it, including `UIStroke` thickness and text, so keep the HUD in a separate `ScreenGui` with its own responsive rules ([[Responsive UI for Phone Tablet Console and PC]]).

For the 2.5D route, none of this is needed for the world; the HUD still follows the normal UI rules.

---

## 8. Input differs too

- **GUI 2D** must build its own touch controls. Default Roblox touch controls move a 3D character, which you do not have. Disable them and draw a D-pad or virtual stick plus buttons inside the safe area. Keyboard and gamepad come through `UserInputService` or `ContextActionService` as usual ([[Input - UserInputService and ContextActionService]], [[Gamepad and Console UX]]). Do not hang gameplay input on GUI button `Activated` events alone: they fire on release for some input types and make jumping feel late. Track press state directly ([[Input Responsiveness Buffering and Coyote Time]]).
- **2.5D** can keep the default touch thumbstick if you project its move vector onto the plane, which players find natural. Turn off camera rotation and zoom; on touch, the drag-to-rotate gesture must do nothing.

---

## 9. Worked decisions

**A. Solo pixel-art roguelike, cosmetic unlocks only.** No visible other players, art identity is crisp pixels, exact rules wanted. **GUI 2D**, fixed 320 x 180 logical resolution, integer scale, summary validation for unlock progress. Lobby is a small 3D room where players see each other and pick runs, which recovers the social layer.

**B. Four-player co-op side-scroller with avatars.** Visible players, physics toys, engine effects. **2.5D** with a side camera at FOV about 30, plane locking on characters, levels built from parts. GUI only for HUD and menus.

**C. A 3D tycoon that wants a "retro arcade" building.** **Hybrid**: the cabinets are parts with a `SurfaceGui` (or the player sits down and a full-screen `ScreenGui` opens). The minigame is GUI 2D, single-player, scores go through summary validation, and the room around it stays social.

**D. 1v1 real-time 2D fighting game.** This is the trap. GUI 2D gives exact hitboxes but no netcode; 2.5D gives netcode but not frame-exact hitboxes. The answer that works is GUI 2D rendering with a **server-simulated** fixed-step model and client prediction, which is a large project. If the team has not shipped networked games before, prototype the netcode first, before any art, and be ready to fall back to a slower-paced design.

---

## 10. Common mistakes

- **Choosing GUI 2D for a multiplayer action game "because it is simpler".** It is the opposite. Symptom: weeks in, players cannot see each other move smoothly and the team is reinventing interpolation.
- **Moving the GUI playfield with `Scale` values.** Positions in scale units mean a jump height of 0.1 is a different number of pixels on every device; collisions and level design break. Author in logical pixels (offset) and scale the whole world once.
- **Creating and destroying GuiObjects every frame.** Instance churn is the most common GUI 2D frame-rate killer. Pool and reuse ([[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]).
- **Trusting client scores.** A GUI 2D game with an unvalidated global leaderboard will be topped by cheaters in days.
- **2.5D without correcting depth drift.** Players get pushed a few studs off the plane by another player and fall behind the level art.
- **Ignoring safe areas.** GUI 2D touch buttons placed in the notch or behind the home indicator.

---

## 11. Checklist

- [ ] Answered: do other players need to be visible and moving in the world? If yes, default to 2.5D.
- [ ] Answered: is pixel exactness part of the art identity or rules? If yes, lean GUI 2D.
- [ ] Listed what the game must do that the chosen route does not give for free (particles, physics toys, netcode, level editor) and estimated each.
- [ ] Picked a screen policy (letterbox, fixed height, fixed width) and a logical resolution for GUI 2D.
- [ ] Planned server checks for anything valuable produced by client-side play.
- [ ] Planned custom touch controls (GUI 2D) or plane-projected movement and locked camera (2.5D).
- [ ] Prototyped the hardest unknown first: netcode for multiplayer GUI 2D, depth correction for 2.5D, crispness for pixel art in 3D.
- [ ] Kept the HUD in its own ScreenGui, independent of the world scale.

## See also

- [[2D Game Development Start Here]]
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]
- [[Sprite Sheets and Frame Animation with ImageRectOffset]]
- [[2D Collision Physics and Platformer Movement]]
- [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]
- [[Genre Playbook - Obbies and Platformers]]
- [[ScreenGui Fundamentals]]
- [[Camera Systems]]
- [[Planning and Scoping a Roblox Game]]

## Connected notes
<!-- auto-links:start -->
[[EditableImage for Pixel Buffers and Procedural 2D]] · [[Modelling to the Roblox Camera and Player Scale]] · [[Debugging UI Layout and Input]] · [[World-Space UI - BillboardGui and SurfaceGui]] · [[Cookbook - UI]] · [[Links - Containers]]
<!-- auto-links:end -->
