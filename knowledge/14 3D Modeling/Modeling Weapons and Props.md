---
tags: [modeling, weapons, props, grip, pivots, blender, tools, conventions]
---
# Modeling Weapons and Props

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Origin at the pommel or bounding-box centre -> Origin at the grip centre
> - Avoid: Blade modelled along Y or X in Blender -> Blade along +Z
> - Avoid: Edge facing an undefined side -> Edge toward -Y, documented
> - Origin at the grip centre; blade along +Z; edge toward -Y; scale applied.
> - Proportions checked against the character proxy; pommel clears the body.
> - Parts split by role (Handle, Guard, Blade, Glow) and by motion (one object per moving piece).
>
> Cost: TL;DR ~160 tok · whole note ~4.2k tok. Read more: ## 1. The weapon contract · ## 3. Building a sword, step by step · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A weapon is the most-looked-at model in a combat game: it is in the player's hand on every frame, in every icon, every trade, every inspect screen. It also has the strictest technical contract of any static model, because animators, VFX artists and programmers all build on its axes: where the grip is, which way the blade points, where the edge faces, where the trail starts and ends. A sword with a beautiful blade and an arbitrary pivot costs the team more than an ugly sword with the right one.

This note gives the axis and pivot conventions that one live action game (the reference project, about 150 animated weapons) used and that the Animation section's rigs, IK and QA tools depend on, then covers how to model blades, hafts, guards and moving parts, budgets, and the same discipline for interactive props (chests, doors, wheels, stations).

Related: [[Custom Rigs - Weapons and Props]] (rigging these models), [[Weapon Swing Design]] and [[Procedural Weapon Motion]] (animating them), [[Weapon Design Rig Builder]] (turning imports into rigs).

---

## 1. The weapon contract

Write these down for your project once. Everything downstream reads them.

### In-game hand-space conventions (from the reference project)

| Convention | Value |
|---|---|
| Blade direction | Along the hand's **-Z** (LookVector) |
| Edge direction | The hand's **-X** (some kits used -Y; pick one and keep it) |
| Grip point | On the hand's `RightGripAttachment` (measured at 0, -0.158, 0 in the hand, rotated -90 degrees about X on the default rig) |
| Default grip position along the weapon | 28 percent from the pommel end, unless the model sets `GripExact = true` |
| Pommel length assumed by QA | About 20 percent of the blade length behind the grip |
| Scythe | Held by its Handle 1.1 studs from the butt, shaft along -Z, head on the hand's +Y side |
| Staff | Held at the centre of its grip parts; trail attachments at both ends; halves tagged "A" and "B" for split moves |

Sources: [[Custom Rigs - Weapons and Props]] and [[R15 Rig Anatomy and Attachments]].

### Modelling conventions in Blender that produce that

Blender is Z-up; GLB export with *+Y Up* turns Blender +Z into glTF +Y, and Studio's GLB import turns the model 180 degrees about Y (see [[Enemy Import Axis Fix]]). The net mapping is: Blender +Z becomes Roblox +Y; Blender -Y becomes Roblox -Z. So model weapons like this:

| Element | Blender |
|---|---|
| Origin | **Grip centre** (the middle of where the hand closes), at 0,0,0 |
| Blade / shaft | Along **+Z** (pointing up) |
| Pommel | Along -Z, below the origin |
| Cutting edge (single-edged blades) | Facing **-Y** (the model's "front") |
| Flat of the blade | Facing ±X |
| Scale | Final stud size, applied |

Imported this way, the weapon's model space has the blade along +Y and the edge along -Z. The hold code then maps that onto the hand convention with one fixed `Tool.Grip` (below). The reference project's setup format described blades by their "Y span" in design space (for example `--blade-y y0,y1`), which is exactly this layout.

### Computing Tool.Grip from the convention

The Tool system welds `Handle` to the hand with `C0 = RightGripAttachment.CFrame` and `C1 = Tool.Grip`, so `Handle = Hand * C0 * Grip:Inverse()`. Choose where the handle should sit relative to the hand, and solve for `Grip`:

```lua
--!strict
-- Compute Tool.Grip so a weapon modelled "blade +Y, edge -Z, origin at grip"
-- is held with blade along hand -Z and edge along hand -X.
local function gripFor(gripAttachment: Attachment, offsetAlongBlade: number?): CFrame
	-- Desired Handle frame in hand space:
	--   handle +Y (blade) -> hand -Z
	--   handle +Z (back of blade, since the edge is -Z) -> hand +X (edge -Z -> hand -X)
	--   handle +X = Y x Z -> hand -Y
	local handleInHand = CFrame.fromMatrix(
		gripAttachment.Position,       -- grip point in hand space
		Vector3.new(0, -1, 0),         -- handle X axis expressed in hand space
		Vector3.new(0, 0, -1)          -- handle Y axis (blade) expressed in hand space
	) * CFrame.new(0, -(offsetAlongBlade or 0), 0)   -- slide the weapon if the origin is not the grip
	-- Handle = Hand * C0 * Grip^-1 with C0 = gripAttachment.CFrame
	return handleInHand:Inverse() * gripAttachment.CFrame
end

-- Usage (on a character rig in Workspace):
-- tool.Grip = gripFor(character.RightHand.RightGripAttachment)
```

Verify numerically rather than by eye: after equipping, `hand.CFrame:VectorToObjectSpace(handle.CFrame.UpVector)` should be close to `(0, 0, -1)`. The reference project's weapon pipeline verified every new weapon with a hold test reporting "grip-to-hand < 0.5" studs, and its arm QA measured hand, blade direction and edge errors per animation frame ([[Arm QA Metrics Reference]]).

---

## 2. Proportions and readability

- **Length against the character.** Model with the R15 proxy at your game's scale in the scene. The reference project's players were about 9 studs tall; weapon lengths ran from about 4.6 studs for a mid-size sword up to 7.1 studs for a top-tier greatsword (its `WeaponLength` values).
- **Exaggerate width.** Real blades are thin; game blades need a readable flat. A blade's width of about 12-20 percent of its length reads at game distance (rule of thumb); real swords are closer to 4-6 percent.
- **Chunky guard and pommel.** These carry the weapon's identity in the silhouette and in icons.
- **Pommels must clear the body.** The project's arm QA flagged long pommels "buried in the hip and torso". The fix was in the animation (hands further from the body), but a modeller can help: keep pommels under about 20 percent of the blade length unless the design needs a long haft.
- **One focal glow.** Glowing cores, runes and edge strips read as rarity. Keep neon to about 5-8 percent of the weapon (the outlined voxel style's rule: "dark blade core, gold guard, neon edge strip").

---

## 3. Building a sword, step by step

Worked example: a stylised longsword, total 5.5 studs, mid-poly (bevel workflow from [[Hard-Surface Modeling]]).

1. **Proxy and origin.** Place the 3D cursor at the world origin. This is the grip centre.
2. **Grip.** An 8-sided cylinder, radius 0.13, length 1.0, centred on the origin along Z. Loop-cut two wraps and scale them out slightly for a leather-wrap read.
3. **Pommel.** A UV sphere or bevelled octagon at Z = -0.65, radius 0.2, slightly flattened along Y.
4. **Guard.** A box 1.4 x 0.25 x 0.18 at Z = +0.55, tapered toward the tips (scale the end loops down), tips curved slightly toward the blade.
5. **Blade.** A plane 0.55 wide (X) and 3.6 long (Z) starting at Z = 0.65. Loop-cut once along the length (the fuller line) and once across near the tip. Merge the tip vertices to a point. Add a Solidify of 0.08 (blade thickness) and pull the centre loop out along ±Y to make a diamond cross-section; the edges stay thin.
   - For a single-edged blade, keep the spine thick on +Y and the edge sharp on -Y.
6. **Bevel** the guard and pommel (width 0.02-0.03, 2 segments, limit by angle); blade edges usually get no bevel (a sharp edge catches a crisp highlight).
7. **Shading**: Smooth by Angle around 30 degrees on the blade so the bevel planes stay flat; weighted normals on guard and pommel.
8. **Glow part**: duplicate the fuller loop's faces into a separate object `EdgeGlow` (or a core strip) for a Neon material in Roblox.
9. **Markers**: add empties or tiny meshes for VFX attachments at the blade base and tip. The importer converts meshes named with `_Att` to Attachments (Docs), for example `TrailTop_Att`, `TrailBottom_Att`.
10. **Split into parts by role**: `Handle` (grip + pommel, the root), `Guard`, `Blade`, `EdgeGlow`. Static parts can also be joined into one mesh; split only what needs its own material or motion.
11. **Apply transforms**, check triangles (a mid-poly sword like this is 800-2,500 triangles), export GLB.

### Naming that scripts can trust

The reference project's grip finder searched names and once matched "bit" (as in a blade bit) inside `Orbit_*` parts, moving the grip to 18 percent from the butt on 11 weapons. Lessons:
- Name the grip part exactly `Handle` (Tool convention) or `Grip`.
- Mark special parts with **attributes or tags** in Studio rather than relying on name substrings.
- Avoid dots and spaces in names.

---

## 4. Moving parts: model them for the rig

Animated weapons (unfolding blades, orbiting rings, opening jaws, chains) are rigged with one Motor6D per moving piece in Studio (see [[Weapon Design Rig Builder]]). The modeller's job:

- **One object per moving piece**, named after the piece (`Ring`, `Seg1`, `Seg2`, `JawUpper`). Clips key joints by the moving part's name; a keyed piece without its own part is silently inert.
- **Origin of each moving piece on its hinge or spin centre.** If origins are wrong, record the hinge points separately (the project's parts-JSON route exported a `joint = {x, y, z}` pivot per hinge).
- **Hinge axes along model axes** where possible. The project's in-house route built joints with identity rotation at each pivot, so "hinge axes are the model axes"; a tilted hinge needs its axis written down explicitly or it ends up "guessed from geometry" and needs a playtest.
- **Chained pieces** (a segmented whip, a ribbon) as separate segments with origins at each link joint.
- **Chains that hang**: model them, but expect them to be welded rigid or animated as hinges; physics chains on a held, massless, replicated weapon jitter ([[Custom Rigs - Weapons and Props]]).
- **Orbiting pieces** (shards, halos, pixels): separate objects, centred so a spin about one axis looks right. The project's hand-built swords used 3 to 7 orbiting pieces driven by Motor6Ds or welds.

Budgets from the reference project's own Blender swords: **32 parts, 26.8k triangles** (a code-themed mythic with brace-shaped guard halves, a screen core and three orbiting pixel cubes on Motor6Ds) and **32 parts, 29.5k triangles** (a top-tier greatsword with a prism core, infinity-sign guard, accretion disc, sunburst halo, floating tip shards and 7 orbiting crystals; 5 Motor6Ds). These are top-rarity showpieces: one per player, worth the cost. Commons should be a fraction of that (rule of thumb: 1-5k).

---

## 5. Weapon types: what changes

| Type | Modelling notes |
|---|---|
| Katana, saber | Single edge facing -Y; gentle curve along the spine; long two-hand grip (origin at the upper hand's grip unless your rig uses a two-hand grip point) |
| Greatsword | Exaggerated width and guard; grip long enough for two hands; long pommel risk |
| Axe, hammer | Head mass far from the grip; head's striking face toward -Y; weight reads through size, not detail |
| Spear, polearm | Shaft along +Z; grip origin a third up from the butt (or wherever your hold puts the lead hand) |
| Scythe | Blade on the haft's side; reference project: held 1.1 studs from the butt, head on the hand's +Y side. The first scythe set failed QA because heads were rotated 90 degrees |
| Staff, double-ended | Origin at the centre of the grip; symmetric; halves as separate objects if split moves exist |
| Bow | String as a separate object if it animates; origin at the grip in the riser |
| Gun | Barrel along +Z (so it maps onto the hand's -Z); muzzle marker `Muzzle_Att`; magazine separate if reload animates |
| Fist weapons, gauntlets | These are worn, not held: model around the R15 hand part box (see [[Modeling Characters for R15 and Custom Rigs]]) |

---

## 6. Props: the same discipline

Interactive props behave like small rigs. The reference project's hub props show the pattern.

### Chests and lids

The daily reward chest (8k triangles) was a Model with PrimaryPart `Base`, pivot at the base bottom facing the chest front, and a `Lid` that "swings about Base.Hinge attachment" with an `OpenAngle` of 105 degrees. Modelling requirements:
- Lid as its own object with its **origin on the hinge line**, hinge along a model axis (X).
- Base with an empty or `Hinge_Att` marker on the hinge.
- Inner glow and treasure as separate objects (shown only when open).
- Close clearance: the lid must not intersect the base anywhere in its swing range (the project checked its overshoot range so the lid "never dips into the plinth").

### Doors, wheels, spinners

- **Origin on the hinge or axle.** The prize spinner's `Wheel` was a separate mesh spinning about its axle, with the pointer flapper separate.
- **Separate meshes for lights that animate** (bulbs in chase groups `BulbsA/B/C`, each a single mesh so one property change lights the group).

### Animated sub-models

The project animated hub props without rigs: sub-models named `Anim_<name>` with an `AnimPivot` attachment and an `AnimAxis` attribute, driven by one client script. To support that, model each moving group as its own object with its origin on its pivot, and keep the pivot axis along a world axis. When a whole station is moved by a rigid transform, those pivots and axes must move with it ([[Custom Rigs - Weapons and Props]] section 7).

### Collision

Visual meshes with many triangles make poor and expensive colliders. The project's hub pieces had visual meshes with `CanCollide` off plus a few invisible box colliders (for example "13 invisible blocks" for a large station, because, in its measurement, a script could not set `CollisionFidelity` on uploaded meshes). Model simple collider blocks in Blender alongside the art, or place Parts in Studio. See [[Collision and Physics Geometry]].

---

## 7. Held weapon technical settings in Studio

These are not modelling tasks, but models must allow them:

- All weapon parts **unanchored, Massless, CanCollide/CanTouch/CanQuery false**; a held weapon must not add mass or collisions to the character.
- The `Handle` is the PrimaryPart and the rig root.
- Keep separate glow parts so `Material = Neon` can be set without affecting the blade.

---

## 8. Icons and inspect views

Weapons appear huge in icons and inspect screens, so close-up quality matters more than for most props. The reference project rendered every weapon icon with a background Blender render from the weapon's GLB, using a part-look file from Studio (material, colour, transparency per part) so the render matched the game. Model with that in mind: the icon camera sees the guard and blade flat at a 3/4 angle; detail there pays off. See [[Icon and Thumbnail Rendering Pipeline]].

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Origin at the pommel or bounding-box centre | Weapon held at the wrong point; Grip guesses | Origin at the grip centre |
| Blade modelled along Y or X in Blender | Held sideways or pointing at the player | Blade along +Z |
| Edge facing an undefined side | Slashes lead with the flat | Edge toward -Y, documented |
| Moving pieces joined to the blade | Clip "plays", nothing moves | One object per moving piece |
| Hinge origins not on the hinge | Pieces swing around the wrong point | Origins on hinges, or export pivots |
| Name-based grip detection | Grip jumps on some models | Exact names, attributes, tags |
| Long pommels | Clips into hip and torso in swings | Keep under ~20 percent of blade length |
| Thin realistic blade | Invisible from the side | Exaggerated width and thickness |
| Lid origin at the box centre | Lid rotates through the box | Origin on the hinge |

## Checklist

- [ ] Origin at the grip centre; blade along +Z; edge toward -Y; scale applied.
- [ ] Proportions checked against the character proxy; pommel clears the body.
- [ ] Parts split by role (Handle, Guard, Blade, Glow) and by motion (one object per moving piece).
- [ ] Each moving piece's origin on its hinge; hinge axes along model axes or documented.
- [ ] VFX markers (`_Att`) at blade base, tip, muzzle.
- [ ] Triangles within the rarity budget.
- [ ] Hold verified numerically in Studio (blade direction, grip distance).
- [ ] Props: lids, doors and wheels pivot on their hinges; colliders separate and simple.

## See also

[[Custom Rigs - Weapons and Props]] · [[Weapon Design Rig Builder]] · [[Pipeline - New Animated Weapon]] · [[Weapon Swing Design]] · [[Equip Draw and Flourish Systems]] · [[Tools and Inventory Systems]] · [[Hard-Surface Modeling]] · [[Modular Environment Kits]] · [[Icon and Thumbnail Rendering Pipeline]] · [[Tween and CFrame Animation of Objects]]

## Connected notes
<!-- auto-links:start -->
[[Weapon and Combat Animation]] · [[Rigs and Joints]] · [[Modeling Fundamentals for Games]] · [[Blender Workflow for Roblox Creators]] · [[Stylised Weapons From a Concept]] · [[Skeleton Library]]
<!-- auto-links:end -->
