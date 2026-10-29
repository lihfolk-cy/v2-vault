---
tags: [2d, collision, physics, platformer, movement, tilemap, aabb, coyote-time, jump, luau, type/guide, area/2d]
---
# 2D Collision Physics and Platformer Movement

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Resolving both axes at once. Symptom: snagging on seams between floor tiles; random wall-sticking.
> - Avoid: `x + w` instead of `x + w - 1` in tile ranges.
> - Avoid: Float positions without a remainder model.
> - AABB colliders, tile grid, integer positions with remainders.
> - Move X then Y, one pixel at a time; zero remainder on block.
> - Out-of-bounds policy decided (walls, sky, pit).
>
> Cost: TL;DR ~140 tok · whole note ~5.9k tok. Read more: ## 3. Moving: one axis, one pixel at a time · ## 5. The controller · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

A GUI 2D game has no physics engine. Every floor you stand on, every wall you slide along and every jump arc is your code. The good news is that 2D platformer physics is a solved problem with a small, robust core: axis-aligned boxes, a tile grid, movement one axis at a time, and a handful of tuning numbers derived from how the jump should feel. This note gives that core in strict Luau, explains why it is built that way, and covers the parts that usually go wrong: tunnelling, corner snags, one-way platforms, slopes, moving platforms, stomps, and the tuning math.

It assumes the loop and data layout from [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] (fixed 60 Hz step, logical pixels, Y grows downward). General intersection math (segment tests, swept boxes, SAT) is in [[Intersection and Collision Math]]; the feel layer (buffering and coyote time in depth) is in [[Input Responsiveness Buffering and Coyote Time]]. If you chose the 2.5D route, section 9 maps the same tuning onto Roblox physics.

Source labels: **Roblox docs (as of October 2026)** where engine behaviour is involved; most of this note is engine-independent technique labelled **rule of thumb** or shown by arithmetic.

---

## 1. Design choices that make everything else simple

| Choice | Why |
|---|---|
| Every collider is an axis-aligned box (AABB) | Overlap is four comparisons; resolution has only two axes; no rotation math |
| Level geometry is a tile grid | Finding what a box touches is integer division, not a search |
| Positions are **whole logical pixels**, with a fractional remainder carried separately | No floating-point "almost touching" states; exact standing on floors; pixel-perfect rendering for free |
| Move one pixel at a time, X first, then Y | Cannot tunnel, cannot snag on tile seams, collision side is always known |
| Velocity in pixels per second, applied in the fixed step | Frame-rate independent ([[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]) |

The integer-position, pixel-stepping approach is the one used by many well-known 2D platformers precisely because it has so few failure modes. Its cost is a loop iteration per pixel moved, which is trivial at platformer speeds (a fast fall of 6 pixels per step is 6 tiny tile lookups).

**When not to use it:** very fast projectiles (a bullet at 30 pixels per step makes 30 checks; use a ray or swept test from [[Intersection and Collision Math]] instead), large physics-heavy worlds, or rotating bodies. Those are signs you might want the 2.5D route ([[Choosing GUI 2D or Locked-Camera 2.5D]]).

---

## 2. Tiles and the overlap test

```lua
--!strict
-- Collide: tile-grid collision with integer positions and pixel stepping.
local Collide = {}

Collide.EMPTY = 0
Collide.SOLID = 1
Collide.ONEWAY = 2 -- solid from above only

export type TileMap = {
	tileSize: number, -- logical pixels, e.g. 16
	width: number, -- in tiles
	height: number, -- in tiles
	tiles: { number }, -- row-major, 1-based: index = ty * width + tx + 1
}

export type Body = {
	x: number, -- integer, left edge
	y: number, -- integer, top edge
	w: number,
	h: number,
	remX: number, -- fractional movement not yet applied
	remY: number,
	grounded: boolean,
	ignoreOneWayUntil: number, -- simulation time; for dropping through platforms
}

function Collide.tileAt(map: TileMap, tx: number, ty: number): number
	if tx < 0 or tx >= map.width then
		return Collide.SOLID -- level edges are walls
	end
	if ty < 0 or ty >= map.height then
		return Collide.EMPTY -- open sky above, a pit below (death handled elsewhere)
	end
	return map.tiles[ty * map.width + tx + 1] or Collide.EMPTY
end

-- True if the box overlaps any SOLID tile. One-way tiles are handled separately.
function Collide.solidAt(map: TileMap, x: number, y: number, w: number, h: number): boolean
	local ts = map.tileSize
	for ty = y // ts, (y + h - 1) // ts do
		for tx = x // ts, (x + w - 1) // ts do
			if Collide.tileAt(map, tx, ty) == Collide.SOLID then
				return true
			end
		end
	end
	return false
end

-- True if the body's feet rest exactly on top of a one-way tile.
function Collide.oneWayUnder(map: TileMap, x: number, y: number, w: number, h: number): boolean
	local ts = map.tileSize
	local feet = y + h
	if feet % ts ~= 0 then
		return false -- feet are not on a tile boundary
	end
	local ty = feet // ts
	for tx = x // ts, (x + w - 1) // ts do
		if Collide.tileAt(map, tx, ty) == Collide.ONEWAY then
			return true
		end
	end
	return false
end
```

Three details carry most of the correctness:

- **`x + w - 1`, not `x + w`.** A 16-pixel-wide box at `x = 0` covers pixels 0 to 15, which is tile 0 only. Using `x + w` puts its right edge in tile 1, and the player "collides" with walls they are only touching. This off-by-one is the cause of "my character cannot walk through a one-tile-wide gap that it should fit through".
- **`//` is floor division.** For negative coordinates (left of the map), `-1 // 16` is `-1`, which is correct; truncating division would give 0 and put things left of the map inside tile 0.
- **Out-of-bounds policy is explicit.** Sides are walls, the top is open, the bottom is a pit. Change this per game, but decide it; the default of "index out of range returns nil" makes the edge of the map behave differently from the middle.

---

## 3. Moving: one axis, one pixel at a time

```lua
-- Move horizontally by a (possibly fractional) amount. Returns true if blocked.
function Collide.moveX(map: TileMap, b: Body, amount: number): boolean
	b.remX += amount
	local move = math.round(b.remX)
	if move == 0 then
		return false
	end
	b.remX -= move
	local dir = if move > 0 then 1 else -1
	while move ~= 0 do
		if Collide.solidAt(map, b.x + dir, b.y, b.w, b.h) then
			b.remX = 0
			return true
		end
		b.x += dir
		move -= dir
	end
	return false
end

-- Move vertically. One-way tiles block only downward movement onto their top.
function Collide.moveY(map: TileMap, b: Body, amount: number, now: number): boolean
	b.remY += amount
	local move = math.round(b.remY)
	if move == 0 then
		return false
	end
	b.remY -= move
	local dir = if move > 0 then 1 else -1
	local useOneWay = now >= b.ignoreOneWayUntil
	while move ~= 0 do
		local blocked = Collide.solidAt(map, b.x, b.y + dir, b.w, b.h)
		if not blocked and dir == 1 and useOneWay then
			blocked = Collide.oneWayUnder(map, b.x, b.y, b.w, b.h)
		end
		if blocked then
			b.remY = 0
			return true
		end
		b.y += dir
		move -= dir
	end
	return false
end

function Collide.updateGrounded(map: TileMap, b: Body, now: number)
	b.grounded = Collide.solidAt(map, b.x, b.y + 1, b.w, b.h)
		or (now >= b.ignoreOneWayUntil and Collide.oneWayUnder(map, b.x, b.y, b.w, b.h))
end

return Collide
```

Why this shape works:

- **Separate axes** mean a blocked move always knows its side: if `moveX` is blocked, it was a wall; if `moveY` is blocked going down, it was a floor. Resolving both axes at once from a diagonal overlap has to guess which side was hit, and guesses wrong at tile corners, which is the famous "catching on the seam between two floor tiles" bug.
- **Pixel stepping cannot tunnel.** Every intermediate pixel is checked. A falling player at terminal velocity still stops on a one-pixel-thick ledge.
- **The remainder carries sub-pixel motion.** A walk speed of 45 pixels per second at 60 Hz is 0.75 pixels per step; the remainder accumulates and the body moves 3 pixels every 4 steps, perfectly even. Zeroing the remainder on a hit stops a body pressed against a wall from building up "pressure" that releases as a jump when the wall ends.
- **One-way logic is a single rule**: a one-way tile blocks only a body moving down whose feet are exactly on the tile's top edge. Jumping up through it, walking into it sideways and standing inside it are all naturally allowed. Dropping through is a time window (`ignoreOneWayUntil`), which is more robust than a single-step flag because the body needs several steps to clear the tile.

`math.round` on the remainder rounds halves away from zero, which is consistent in both directions. Using `math.floor` instead biases movement: leftward motion would move a step earlier than rightward motion at the same speed.

---

## 4. Platformer tuning from feel, not guesses

Pick the jump by what the player experiences, then derive the physics. With jump height `h` (pixels) and time to apex `t` (seconds), constant gravity gives:

- gravity `g = 2h / t²`
- launch speed `v = 2h / t`

Worked example: a 16-pixel tile game where the jump should clear 3.5 tiles (`h = 56`) and reach the top in 0.38 s:

- `g = 2 x 56 / 0.1444 = 775.6` pixels per second squared
- `v = 2 x 56 / 0.38 = 294.7` pixels per second
- Check: `v² / 2g = 86,848 / 1,551.2 = 56` pixels. Correct.

Tuning by guessing `g` and `v` separately means every change to one breaks the other; deriving them lets a designer say "a bit higher, a bit snappier" and change two numbers that mean something.

| Parameter | Typical starting value (rule of thumb, 16 px tiles, 60 Hz) | What it does |
|---|---|---|
| Run speed | 90 to 150 px/s (about 6 to 9 tiles/s) | Sets level pacing and gap widths |
| Ground acceleration | Reach run speed in 0.05 to 0.12 s | Responsiveness; too slow feels icy |
| Ground deceleration | Stop in 0.04 to 0.10 s | Precision on small platforms |
| Air acceleration | 50 to 80% of ground acceleration | Air control; 0% feels stiff and old-fashioned |
| Jump height | 3 to 4.5 tiles | Defines what geometry is reachable |
| Time to apex | 0.30 to 0.45 s | Floaty versus snappy |
| Fall gravity multiplier | 1.5 to 2.5 | Faster fall than rise: the jump feels weighty, not floaty |
| Jump cut multiplier | Velocity x 0.4 to 0.5 on early release | Variable jump height |
| Max fall speed | 250 to 400 px/s | Keeps falls readable and stops tunnelling with swept tests |
| Coyote time | 0.06 to 0.10 s | Jump just after leaving a ledge still works |
| Jump buffer | 0.08 to 0.15 s | Jump pressed just before landing still fires |

Fall gravity changes the arc's descent, so the horizontal distance of a full jump is no longer symmetric. Compute the reachable gap for level design as `runSpeed x (t + t_fall)` where `t_fall = sqrt(2h / (g x fallMultiplier))`. For the example with a multiplier of 2: `t_fall = sqrt(112 / 1551.2) = 0.269` s, so at 120 px/s a full jump covers `120 x 0.649 = 78` pixels, a little under 5 tiles. Give level designers that number; it is the most important constant in [[Obby and Platforming Level Design]] terms.

---

## 5. The controller

```lua
--!strict
-- PlatformerController: input + tuning -> body movement, one fixed step at a time.
local Collide = require(script.Parent.Collide)

type Body = Collide.Body
type TileMap = Collide.TileMap

export type Input = {
	moveX: number, -- -1..1
	jumpHeld: boolean,
	jumpPressed: boolean, -- true only on the step the press is first consumed
	downHeld: boolean,
}

export type Tuning = {
	runSpeed: number,
	groundAccel: number,
	groundDecel: number,
	airAccel: number,
	gravity: number,
	jumpVelocity: number,
	fallGravityMult: number,
	jumpCutMult: number,
	maxFall: number,
	coyoteTime: number,
	bufferTime: number,
	cornerNudge: number, -- pixels; ceiling corner correction
}

export type Player = {
	body: Body,
	vx: number,
	vy: number,
	coyote: number,
	buffer: number,
	rising: boolean, -- in a jump that can still be cut
}

local Controller = {}

function Controller.tuningFromJump(heightPx: number, apexSeconds: number, base: Tuning): Tuning
	local t = table.clone(base)
	t.gravity = 2 * heightPx / (apexSeconds * apexSeconds)
	t.jumpVelocity = 2 * heightPx / apexSeconds
	return t
end

local function approach(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

function Controller.step(p: Player, input: Input, map: TileMap, t: Tuning, dt: number, now: number)
	local b = p.body

	-- Horizontal velocity
	local target = input.moveX * t.runSpeed
	local accel: number
	if b.grounded then
		accel = if input.moveX ~= 0 then t.groundAccel else t.groundDecel
	else
		accel = t.airAccel
	end
	p.vx = approach(p.vx, target, accel * dt)

	-- Forgiveness timers
	p.coyote = if b.grounded then t.coyoteTime else math.max(0, p.coyote - dt)
	p.buffer = if input.jumpPressed then t.bufferTime else math.max(0, p.buffer - dt)

	-- Drop through a one-way platform: down + jump while standing on one
	if p.buffer > 0 and input.downHeld and b.grounded and Collide.oneWayUnder(map, b.x, b.y, b.w, b.h)
		and not Collide.solidAt(map, b.x, b.y + 1, b.w, b.h) then
		b.ignoreOneWayUntil = now + 0.2
		p.buffer = 0
		p.coyote = 0
	elseif p.buffer > 0 and p.coyote > 0 then
		p.vy = -t.jumpVelocity -- negative is up
		p.buffer = 0
		p.coyote = 0
		p.rising = true
	end

	-- Variable jump height: releasing early cuts upward speed once
	if p.rising and not input.jumpHeld and p.vy < 0 then
		p.vy *= t.jumpCutMult
		p.rising = false
	end
	if p.vy >= 0 then
		p.rising = false
	end

	-- Gravity, heavier while falling
	local g = if p.vy > 0 then t.gravity * t.fallGravityMult else t.gravity
	p.vy = math.min(p.vy + g * dt, t.maxFall)

	-- Move X, then Y
	if Collide.moveX(map, b, p.vx * dt) then
		p.vx = 0
	end

	local wasRising = p.vy < 0
	if Collide.moveY(map, b, p.vy * dt, now) then
		if wasRising then
			-- Ceiling corner correction: if a small sideways nudge frees the head, take it
			local freed = false
			for n = 1, t.cornerNudge do
				for _, dir in { -1, 1 } do
					if not freed and not Collide.solidAt(map, b.x + dir * n, b.y - 1, b.w, b.h) then
						b.x += dir * n
						freed = true
					end
				end
				if freed then
					break
				end
			end
			if not freed then
				p.vy = 0
				p.rising = false
			end
		else
			p.vy = 0
		end
	end

	Collide.updateGrounded(map, b, now)
end

return Controller
```

Notes on the decisions inside:

- **`jumpPressed` is an edge, consumed once.** If the frame ran two steps, only the first sees the press; the buffer then carries it. Producing `jumpPressed` from `UserInputService` events (not polling `IsKeyDown`) is how short taps are not lost between steps ([[Input - UserInputService and ContextActionService]]).
- **Coyote resets to full every grounded step** and is zeroed on jump, so a coyote jump cannot be followed by a second "free" jump in the same window. That double-jump exploit is the most common coyote bug.
- **The jump cut happens once.** Multiplying velocity every step while the button is up would kill the arc almost instantly and feel like hitting a ceiling.
- **Corner correction** (the nudge) is why good platformers forgive clipping the edge of a ceiling block by a couple of pixels. Without it, a jump that is 2 pixels off slams into the corner and drops; players call this "the game cheated". Keep it at 2 to 4 pixels (rule of thumb); larger values let players squeeze through gaps the designer meant to block. A matching **ledge nudge** (pop up onto a ledge when the feet miss it by 1 to 3 pixels while moving horizontally) is the same idea on the other axis.
- **Ground decel versus accel**: separate numbers because stopping precisely matters more than starting quickly. Many players describe a game with slow stopping as "slippery" even when the run speed is fine.

---

## 6. Slopes

Slopes are where 2D physics stops being small. Choose deliberately:

- **No slopes.** Many excellent platformers use only flat tiles. Strongly recommended for a first GUI game.
- **Heightfield slope tiles.** Each slope tile stores a surface height per column (for a 16-pixel tile, 16 numbers). Horizontal movement on a slope adjusts `y` to the surface height of the new column, and a body walking **down** a slope must be snapped down to the surface each step (otherwise it walks off into the air and "bounces" down the slope in tiny falls, with the grounded flag flickering and the run animation stuttering). Snapping should only happen while grounded and only for drops up to a limit (for example the slope's maximum step per pixel, plus one).
- **Separating-axis polygons.** General, but then you have rewritten a physics engine. At this point, reconsider 2.5D.

If you add slopes, restrict them to a few angles (45 and 22.5 degrees are the classic pair) so the tile set and the snapping rule stay simple.

---

## 7. Moving platforms and pushing

Order matters. In each step:

1. Move platforms first, by their integer delta.
2. For each body that was **standing on** the platform at the start of the step (feet on its top edge and horizontally overlapping), move the body by the same delta **through `moveX` and `moveY`**, so a carried body still collides with walls.
3. If a platform moving into a body would push it into a solid tile (the body's move is blocked on the axis the platform pushes), the body is **crushed**: kill it, or push it out the other side by design. Never leave it overlapping, or the next step's collision has no correct answer.
4. Then run the normal player controller.

Two common mistakes: computing riders **after** moving the platform (the rider's feet are no longer on the top edge, so nobody rides), and adding platform velocity to the player's velocity (works until the player jumps off and keeps the platform's speed forever, which is sometimes a desired "momentum" feature, but should be a decision, not an accident).

---

## 8. Entities hitting entities

Enemies, pickups and hazards are box-versus-box overlap tests, not tile collisions. Use a broad phase (a uniform grid) once you have more than a few dozen. Then:

- **Overlap** is strict inequality: `a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h`. Using `<=` counts touching as overlapping, which makes a player standing next to an enemy take damage.
- **Stomp versus hurt.** The player stomps an enemy when they overlap, the player is moving down (`vy > 0`), and the player's bottom **at the start of the step** (`prevY + h`) was at or above the enemy's top. Checking the current position instead turns fast falls into damage instead of stomps, because by the time the overlap is detected the player is already deep inside the enemy.
- **Invulnerability frames** after taking damage (0.5 to 1.5 s, rule of thumb) prevent one touch from dealing damage on 60 consecutive steps.
- **Resolve gameplay, not overlap.** Enemies usually should not physically push the player; overlap triggers damage and knockback velocity, and tile collision does the rest.

---

## 9. The same tuning in 2.5D

If you went the 3D route ([[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]), the derivation in section 4 still applies, in studs instead of pixels:

- `Workspace.Gravity` is global (Roblox docs (as of October 2026): default 196.2 studs per second squared). Changing it changes every unanchored part in the game, so prefer adjusting the character's jump to fit default gravity, or apply extra downward force to the character only (for example a `VectorForce` on the root during falls) for the fall multiplier.
- `Humanoid.JumpHeight` (with `UseJumpPower` false) sets the jump height in studs directly; time to apex is then fixed by gravity: `t = sqrt(2h / g)`. A 7.2-stud jump at 196.2 gives about 0.27 s to apex.
- Coyote time, jump buffering and variable jump height are not built into the default Humanoid; [[Input Responsiveness Buffering and Coyote Time]] shows how to add them, and [[Custom Character Controllers]] covers replacing the controller when the Humanoid fights you.
- Physics is not deterministic and characters are client-owned, so the server must validate speed and position ([[Server Authority and Validation]], [[Network Ownership]]).

---

## 10. Testing the physics

Because everything above is plain data, it is directly testable without a screen:

- Build a tiny map in a table (a floor, a wall, a one-way ledge), spawn a body, step 120 times with scripted input, assert position and `grounded`.
- **Golden jumps:** record that a full jump from standing reaches exactly `h` pixels and lands after N steps. Any tuning change that alters them shows up immediately.
- **Edge cases worth a test each:** walking off a ledge then jumping inside the coyote window; pressing jump 5 steps before landing; jumping into a ceiling corner 2 pixels off; dropping through a one-way platform; standing on two tiles at a seam and walking (must not catch).

See [[Testing Strategies and Frameworks]] for running these in CI.

---

## 11. Common mistakes

- **Resolving both axes at once.** Symptom: snagging on seams between floor tiles; random wall-sticking.
- **`x + w` instead of `x + w - 1` in tile ranges.** Symptom: cannot enter gaps exactly your size; touching counts as colliding.
- **Float positions without a remainder model.** Symptom: standing 0.0001 pixels above the floor, `grounded` flickers, animations stutter.
- **Remainder not zeroed on collision.** Symptom: sliding off a wall edge with a sudden burst of speed.
- **Coyote time not zeroed on jump.** Symptom: a free second jump right after a ledge jump.
- **Jump cut applied every step.** Symptom: short taps barely leave the ground; jump feels capped.
- **Stomp check using the current position.** Symptom: fast falls onto enemies hurt the player.
- **Moving riders after the platform.** Symptom: players slide off moving platforms.
- **Variable timestep.** Symptom: jump height depends on frame rate (see the engine note).

---

## 12. Checklist

- [ ] AABB colliders, tile grid, integer positions with remainders.
- [ ] Move X then Y, one pixel at a time; zero remainder on block.
- [ ] Out-of-bounds policy decided (walls, sky, pit).
- [ ] One-way platforms block only downward movement onto their top; drop-through uses a time window.
- [ ] Jump derived from height and time to apex; fall multiplier, cut multiplier, max fall set.
- [ ] Coyote time and jump buffer implemented, zeroed on use.
- [ ] Ceiling corner correction of 2 to 4 pixels.
- [ ] Moving platforms update first and carry riders through collision; crush handled.
- [ ] Entity overlaps use strict inequality; stomps use previous-step position.
- [ ] Reachable gap distance computed and handed to level design.
- [ ] Headless tests for golden jumps and the edge cases above.

## See also

- [[2D Game Development Start Here]]
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]
- [[Tilemaps Cameras and Parallax for 2D Levels]]
- [[Sprite Sheets and Frame Animation with ImageRectOffset]]
- [[Intersection and Collision Math]]
- [[Input Responsiveness Buffering and Coyote Time]]
- [[Genre Playbook - Obbies and Platformers]]
- [[Obby and Platforming Level Design]]
- [[Custom Character Controllers]]

## Connected notes
<!-- auto-links:start -->
[[Input Buffering]] · Detecting Movement Exploits - Speed Fly Noclip Teleport · [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · Humanoid States and Animation · Mover Constraints and Physics Controllers · Characters and Humanoids
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Input Buffering]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[EditableImage for Pixel Buffers and Procedural 2D]] · [[Pixel Art Pipeline - Aseprite to Roblox Without Blur]]
<!-- related:end -->
